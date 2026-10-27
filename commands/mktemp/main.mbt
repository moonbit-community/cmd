///|
priv suberror MktempError {
  MktempError(String)
}

///|
priv struct Template {
  prefix : String
  width : Int32
  suffix : String
}

///|
fn parse_template(
  template : String,
  suffix : String?,
) -> Template raise MktempError {
  let end = if suffix is Some(_) {
    if !template.has_suffix("X") {
      raise MktempError("with --suffix, template '\{template}' must end in X")
    }
    template.length()
  } else {
    let mut last = template.length()
    while last > 0 && template[last - 1] != 'X' {
      last -= 1
    }
    if last == 0 {
      template.length()
    } else {
      last
    }
  }
  let tail = suffix.unwrap_or(template[end:].to_owned())
  if tail.contains("/") || (@platform.is_windows() && tail.contains("\\")) {
    raise MktempError("invalid suffix '\{tail}', contains directory separator")
  }
  let mut first = end
  while first > 0 && template[first - 1] == 'X' {
    first -= 1
  }
  if end - first < 3 {
    raise MktempError("too few X's in template '\{template}'")
  }
  { prefix: template[:first].to_owned(), width: end - first, suffix: tail, }
}

///|
fn random_letters(length : Int32) -> String raise MktempError {
  let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  let output = StringBuilder()
  let mut count = 0
  while count < length {
    guard @env.rand(length - count) is Some(bytes) else {
      raise MktempError("secure random source is unavailable")
    }
    for byte in bytes {
      if byte.to_int() < 248 {
        output.write_char(alphabet[byte.to_int() % 62].unsafe_to_char())
        count += 1
      }
    }
  }
  output.to_string()
}

///|
fn Template::fill(self : Template) -> String raise MktempError {
  self.prefix + random_letters(self.width) + self.suffix
}

///|
fn mktemp_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut literal = false
  let mut value = false
  for arg in args {
    if literal || value {
      result.push(arg)
      value = false
      continue
    }
    if arg == "--" {
      literal = true
    }
    result.push(if arg == "--tmpdir" { "--tmpdir=" } else { arg })
    value = arg == "--suffix" ||
      arg == "-p" ||
      (
        arg.has_prefix("-") &&
        !arg.has_prefix("--") &&
        arg.find("p") == Some(arg.length() - 1)
      )
  }
  result
}

///|
fn creation_error(error : Error) -> String {
  match error {
    MktempError(message) => message
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    _ => error.to_string()
  }
}

///|
async fn create_unique(template : Template, directory : Bool) -> String {
  for _ in 0..<238328 {
    let candidate = template.fill()
    try {
      if directory {
        @fs.mkdir(candidate, permission=0o700)
      } else {
        let file = @fs.open(
          candidate,
          mode=WriteOnly,
          create_mode=CreateNew,
          permission=0o600,
        )
        file.close()
      }
    } catch {
      @os_error.OSError(_) as error if error.is_EEXIST() => continue
      error => raise error
    }
    return candidate
  }
  raise MktempError("File exists")
}

///|
async fn main {
  let parsed = @cli.parse(mktemp_args(@env.args()[1:]), [
    @cli.flag("directory", short='d'),
    @cli.flag("quiet", short='q'),
    @cli.option("tmpdir", short='p'),
    @cli.flag("tmpdir", short='t'),
    @cli.option("suffix"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(kind=MissingOptionValue, option~, ..) => {
      let description = if option == "tmpdir" {
        "option requires an argument -- 'p'"
      } else {
        "option '--suffix' requires an argument"
      }
      @stdio.stderr.write(
        "mktemp: \{description}\nTry 'mktemp --help' for more information.\n",
      )
      @sys.exit(1)
      return
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("mktemp: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: mktemp [OPTION]... [TEMPLATE]\n" +
      "Create an exclusive temporary file (0600) or directory (0700).\n" +
      "  -d, --directory       create a directory\n" +
      "  -p DIR, --tmpdir[=DIR] use DIR, then TMPDIR, then /tmp\n" +
      "  -t                    prefer TMPDIR; reject template directories\n" +
      "      --suffix=SUFFIX   append SUFFIX to a template ending in X\n" +
      "  -q, --quiet           suppress creation and output errors\n" +
      "      --help            display this help and exit\n" +
      "      --version         display version and exit\n" +
      "Default template: tmp.XXXXXXXXXX. The final X run requires at least three Xs.\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("mktemp 0.1.4\n")
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write(
      "mktemp: too many templates\nTry 'mktemp --help' for more information.\n",
    )
    @sys.exit(1)
    return
  }
  let template = parsed.operands.get(0).unwrap_or("tmp.XXXXXXXXXX")
  let spec = parse_template(template, parsed.last_value("suffix")) catch {
    MktempError(message) => {
      @stdio.stderr.write("mktemp: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  let destination = parsed.contains("tmpdir") || parsed.operands.is_empty()
  // -t shares the canonical destination option but has no value occurrence.
  let legacy = parsed.occurrences
    .get("tmpdir")
    .unwrap_or([])
    .any(value => value is None)
  let with_suffix = spec.prefix + "X".repeat(spec.width) + spec.suffix
  if legacy &&
    (
      with_suffix.contains("/") ||
      (@platform.is_windows() && with_suffix.contains("\\"))
    ) {
    @stdio.stderr.write(
      "mktemp: invalid template, '\{with_suffix}', contains directory separator\n",
    )
    @sys.exit(1)
    return
  }
  if destination && !legacy && @path.Path(template).is_absolute() {
    @stdio.stderr.write(
      "mktemp: invalid template, '\{with_suffix}'; with --tmpdir, it may not be absolute\n",
    )
    @sys.exit(1)
    return
  }
  let environment = @env.get_env_var("TMPDIR").filter(value => !value.is_empty())
  let directory_arg = parsed
    .last_value("tmpdir")
    .filter(value => !value.is_empty())
  let directory = if legacy {
    if environment is Some(_) {
      environment
    } else {
      directory_arg
    }
  } else if directory_arg is Some(_) {
    directory_arg
  } else {
    environment
  }
  let directory = directory.unwrap_or("/tmp")
  let spec = if destination {
    {
      ..spec,
      prefix: directory +
      (if directory.has_suffix("/") || directory.has_suffix("\\") {
        ""
      } else {
        "/"
      }) +
      spec.prefix,
    }
  } else {
    spec
  }
  let display_template = spec.prefix + "X".repeat(spec.width) + spec.suffix
  let make_directory = parsed.contains("directory")
  let quiet = parsed.contains("quiet")
  let result = create_unique(spec, make_directory) catch {
    error => {
      if !quiet {
        let kind = if make_directory { "directory" } else { "file" }
        @stdio.stderr.write(
          "mktemp: failed to create \{kind} via template '\{display_template}': \{creation_error(error)}\n",
        )
      }
      @sys.exit(1)
      return
    }
  }
  @stdio.stdout.write(result + "\n") catch {
    error => {
      if make_directory {
        @fs.rmdir(result) catch {
          _ => ()
        }
      } else {
        @fs.remove(result) catch {
          _ => ()
        }
      }
      if !quiet {
        @stdio.stderr.write("mktemp: write error: \{creation_error(error)}\n")
      }
      @sys.exit(1)
    }
  }
}
