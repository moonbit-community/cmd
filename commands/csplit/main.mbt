///|
struct Output {
  prefix : String
  width : Int32
  suffix : SuffixFormat?
  quiet : Bool
  elide : Bool
  paths : Array[String]
}

///|
priv suberror OutputNameError {
  UnsupportedOutputName
}

///|
fn Output::path(self : Output, number : Int32) -> String raise OutputNameError {
  let suffix = match self.suffix {
    Some(format) => format.render(number)
    None =>
      String::make(
        @cmp.maximum(0, self.width - number.to_string().length()),
        '0',
      ) +
      number.to_string()
  }
  let path = self.prefix + suffix
  if @platform.is_windows() && (path.has_suffix(" ") || path.has_suffix(".")) {
    raise UnsupportedOutputName
  }
  path
}

///|
async fn Output::write(
  self : Output,
  input : Snapshot,
  first : Int64,
  end : Int64,
) -> Unit {
  let start = input.offset(first)
  let stop = input.offset(end)
  if self.elide && start == stop {
    return
  }
  let path = self.path(self.paths.length())
  if @fs.exists(path) {
    fail("existing output is unsupported: \{path}")
  }
  let file = @fs.create(path, allow_existing=false)
  self.paths.push(path)
  defer file.close()
  input.copy(start, stop, file)
  if !self.quiet {
    @stdio.stdout.write("\{stop - start}\n")
  }
}

///|
async fn partition(
  data : Snapshot,
  controls : Array[Control],
  output : Output,
  suppress : Bool,
) -> Unit {
  let count = data.records
  let mut first = 0L
  let mut searched = -1L
  for control in controls {
    let mut repetition = 0L
    while control.repeats is None ||
          (control.repeats is Some(n) && repetition <= n.to_int64()) {
      let (cut, ignored) = match control.pattern {
        Line(number) => {
          let target = number.to_int64() * (repetition + 1L) - 1L
          if target >= count {
            output.write(data, first, count)
            fail("line number out of range")
          }
          let target = @cmp.maximum(first, target)
          searched = @cmp.maximum(searched, target - 1)
          (target, false)
        }
        Expression(regex, offset, ignored) => {
          let mut found = None
          let begin = @cmp.maximum(first, searched + 1)
          for line = begin; line < count; line = line + 1 {
            if data.matches(line, regex) {
              found = Some(line)
              break
            }
          }
          match found {
            None => {
              if !ignored {
                output.write(data, first, count)
              }
              if control.repeats is None {
                return
              }
              fail("match not found")
            }
            Some(line) => {
              let target = line + offset.to_int64()
              if target < first || target > count {
                if !ignored && target > count {
                  output.write(data, first, count)
                }
                fail("line number out of range")
              }
              searched = @cmp.maximum(line, target)
              (target, ignored)
            }
          }
        }
      }
      if !ignored {
        output.write(data, first, cut)
      }
      first = if suppress && cut < count { cut + 1 } else { cut }
      repetition += 1
    }
  }
  output.write(data, first, count)
}

///|
async fn process(
  reader : &@io.Reader,
  controls : Array[Control],
  output : Output,
  suppress : Bool,
) -> Unit {
  process_spool(
    @fs.tmpdir(prefix="csplit-"),
    reader,
    controls,
    output,
    suppress,
  )
}

///|
async fn process_spool(
  directory : String,
  reader : &@io.Reader,
  controls : Array[Control],
  output : Output,
  suppress : Bool,
) -> Unit {
  defer @fs.rmdir(directory, recursive=true)
  let data = @fs.open(
    directory + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer data.close()
  let index = @fs.open(
    directory + "/index",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer index.close()
  partition(snapshot(reader, data, index), controls, output, suppress)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: csplit [OPTION]... FILE PATTERN...
    #|Split FILE (- for stdin) at line numbers or basic regular expressions.
    #|Patterns: NUMBER, /REGEXP/[OFFSET], %REGEXP%[OFFSET], {N}, {*}
    #|
    #|  -f, --prefix=PREFIX      Use PREFIX instead of xx.
    #|  -n, --digits=NUMBER      Use at least NUMBER suffix digits (default 2).
    #|  -b, --suffix-format=FORMAT  Use one d/i/u/o/x/X conversion for suffixes.
    #|      --suppress-matched    Omit the offset-adjusted split boundary line.
    #|  -s, --silent             Suppress output byte counts.
    #|  -q, --quiet              Same as --silent.
    #|  -k, --keep-files         Keep created fragments after a split error.
    #|  -z, --elide-empty-files  Omit empty output fragments.
    #|      --help               display this help and exit
    #|      --version            display version and exit
    #|
    #|BRE matching includes backreferences, byte classes and word assertions.
    #|Existing output paths and locale-specific matching are unsupported.
    #|Windows output names ending in spaces or dots are rejected before input.
    #|Input is snapshotted with a disk index; temporary write access is required.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("csplit 0.2.3\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.option("prefix", short='f'),
    @cli.option("digits", short='n'),
    @cli.option("suffix-format", short='b'),
    @cli.flag("suppress-matched"),
    @cli.flag("silent", short='s'),
    @cli.flag("quiet", short='q'),
    @cli.flag("keep-files", short='k'),
    @cli.flag("elide-empty-files", short='z'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(message~, option~, ..) => {
      @stdio.stderr.write("csplit: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("csplit 0.2.3\n")
    return
  }
  let (controls, width, suffix) = try {
    guard parsed.operands.length() >= 2 else {
      fail("FILE and PATTERN are required")
    }
    let width = @string.parse_int(parsed.last_value("digits").unwrap_or("2"))
    guard width >= 0 && width <= 1024 else {
      fail("suffix digit count must be between 0 and 1024")
    }
    let suffix = parsed.last_value("suffix-format").map(suffix_format)
    (parse_controls(parsed.operands[1:]), width, suffix)
  } catch {
    SuffixError(message) => {
      @stdio.stderr.write("csplit: " + message + "\n")
      @sys.exit(1)
      return
    }
    @bytere.PatternError(message) => {
      @stdio.stderr.write("csplit: \{message}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("csplit: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  let output : Output = {
    prefix: parsed.last_value("prefix").unwrap_or("xx"),
    width,
    suffix,
    quiet: parsed.contains("silent") || parsed.contains("quiet"),
    elide: parsed.contains("elide-empty-files"),
    paths: [],
  }
  try {
    ignore(output.path(0))
    let path = parsed.operands[0]
    let source = if path == "-" {
      None
    } else {
      Some(@fs.open(path, mode=ReadOnly))
    }
    defer (if source is Some(file) { file.close() })
    let reader : &@io.Reader = match source {
      Some(file) => {
        let reader : &@io.Reader = file
        reader
      }
      None => {
        let reader : &@io.Reader = @stdio.stdin
        reader
      }
    }
    process(reader, controls, output, parsed.contains("suppress-matched"))
  } catch {
    err => {
      let name_boundary = err is UnsupportedOutputName
      @stdio.stderr.write(
        if name_boundary {
          "csplit: unsupported capability: verbatim output names ending in spaces or dots\n"
        } else {
          "csplit: \{err}\n"
        },
      )
      if !parsed.contains("keep-files") {
        for path in output.paths {
          @fs.remove(path) catch {
            cleanup => @stdio.stderr.write("csplit: cleanup: \{cleanup}\n")
          }
        }
      }
      @sys.exit(if name_boundary { 2 } else { 1 })
    }
  }
}
