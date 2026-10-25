///|
priv enum ErrorMode {
  Traditional
  Warn
  WarnNoPipe
  Exit
  ExitNoPipe
}

///|
priv struct Sink {
  name : String
  writer : &@io.Writer
  mut active : Bool
}

///|
fn pipe_error(error : Error) -> Bool {
  match error {
    @io.PipeClosed => true
    @os_error.OSError(code, ..) =>
      if @async.platform is Windows {
        code == 109 || code == 232
      } else {
        code == 32
      }
    _ => false
  }
}

///|
fn error_text(error : Error) -> String {
  if pipe_error(error) {
    return "Broken pipe"
  }
  match error {
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    @os_error.OSError(code, ..) if !(@async.platform is Windows) =>
      match code {
        9 => "Bad file descriptor"
        21 => "Is a directory"
        28 => "No space left on device"
        _ => error.to_string()
      }
    _ => error.to_string()
  }
}

///|
async fn open_error_text(path : String, error : Error) -> String {
  let kind = @fs.kind(path) catch { _ => Unknown }
  if kind is Directory {
    "Is a directory"
  } else {
    error_text(error)
  }
}

///|
fn diagnostic_name(name : String) -> String {
  if !name.is_empty() &&
    name
    .iter()
    .all(c => {
      c
      is ('a'..<='z'
      | 'A'..<='Z'
      | '0'..<='9'
      | '_'
      | '-'
      | '.'
      | '/'
      | ':'
      | '+')
    }) {
    name
  } else {
    "'" + name.replace_all(old="'", new="'\\''") + "'"
  }
}

///|
fn fatal_mode(mode : ErrorMode) -> Bool {
  mode is (Exit | ExitNoPipe)
}

///|
fn ignores_pipe(mode : ErrorMode) -> Bool {
  mode is (WarnNoPipe | ExitNoPipe)
}

///|
fn mode_from_name(value : String) -> ErrorMode? {
  let options = [
    ("warn", Warn),
    ("warn-nopipe", WarnNoPipe),
    ("exit", Exit),
    ("exit-nopipe", ExitNoPipe),
  ]
  for (name, mode) in options {
    if value == name {
      return Some(mode)
    }
  }
  let matching = options.filter(pair => pair.0.has_prefix(value))
  if matching.length() == 1 {
    Some(matching[0].1)
  } else {
    None
  }
}

///|
fn optional_output_error(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut literal = false
  for arg in args {
    result.push(
      if !literal && arg == "--output-error" {
        "--output-error=warn-nopipe"
      } else {
        arg
      },
    )
    if arg == "--" {
      literal = true
    }
  }
  result
}

///|
async fn transfer(
  input : &@io.Reader,
  outputs : Array[Sink],
  mode : ErrorMode,
) -> Int32 {
  let mut failed = false
  while outputs.any(output => output.active) {
    let chunk = input.read_some(max_len=65536) catch {
      error => {
        @stdio.stderr.write("tee: read error: \{error_text(error)}\n")
        return 1
      }
    }
    guard chunk is Some(chunk) else { break }
    for output in outputs {
      if !output.active {
        continue
      }
      output.writer.write(chunk) catch {
        error => {
          output.active = false
          if pipe_error(error) {
            if mode is Traditional {
              @stdio.stderr.write(
                "tee: unsupported capability: SIGPIPE termination\n",
              )
              return 2
            }
            if ignores_pipe(mode) {
              continue
            }
          }
          @stdio.stderr.write(
            "tee: \{diagnostic_name(output.name)}: \{error_text(error)}\n",
          )
          failed = true
          if fatal_mode(mode) {
            return 1
          }
        }
      }
    }
  }
  if failed {
    1
  } else {
    0
  }
}

///|
async fn main {
  let parsed = @cli.parse(optional_output_error(@env.args()[1:]), [
    @cli.flag("append", short='a'),
    @cli.option("output-error"),
    @cli.flag("output-error", short='p'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tee: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: tee [-ap] [--output-error[=MODE]] [FILE...]\n" +
      "  -a, --append             append instead of truncating output files\n" +
      "  -p                       ignore broken output pipes; continue other sinks\n" +
      "      --output-error[=MODE] warn, warn-nopipe, exit, exit-nopipe\n" +
      "      --help               display this help and exit\n" +
      "      --version            display version and exit\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("tee 0.2.2\n")
    return
  }
  let mut mode = Traditional
  for occurrence in parsed.occurrences.get("output-error").unwrap_or([]) {
    if occurrence is Some(value) {
      mode = match mode_from_name(value) {
        Some(mode) => mode
        None => {
          let ambiguous = ["warn", "warn-nopipe", "exit", "exit-nopipe"]
            .filter(name => name.has_prefix(value))
            .length() >
            1
          @stdio.stderr.write(
            "tee: \{if ambiguous { "ambiguous" } else { "invalid" }} argument '\{value}' for '--output-error'\n",
          )
          @stdio.stderr.write(
            "Valid arguments are:\n  - 'warn'\n  - 'warn-nopipe'\n  - 'exit'\n  - 'exit-nopipe'\nTry 'tee --help' for more information.\n",
          )
          @sys.exit(1)
          return
        }
      }
    } else {
      mode = WarnNoPipe
    }
  }
  let files : Array[@fs.File] = []
  defer (for file in files {
    file.close()
  })
  let outputs : Array[Sink] = [
    { name: "standard output", writer: @stdio.stdout, active: true, },
  ]
  let mut opening_failed = false
  for path in parsed.operands {
    let file = @fsops.open_output(
      path,
      if parsed.contains("append") {
        AppendOrCreate
      } else {
        CreateOrTruncate
      },
    ) catch {
      error => {
        @stdio.stderr.write(
          "tee: \{diagnostic_name(path)}: \{open_error_text(path, error)}\n",
        )
        opening_failed = true
        if fatal_mode(mode) {
          @sys.exit(1)
          return
        }
        continue
      }
    }
    files.push(file)
    outputs.push({ name: path, writer: file, active: true, })
  }
  let status = transfer(@stdio.stdin, outputs, mode)
  if status != 0 || opening_failed {
    @sys.exit(if status == 2 { 2 } else { 1 })
  }
}
