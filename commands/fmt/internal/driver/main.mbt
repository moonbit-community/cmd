///|
fn diagnostic(error : Error) -> String {
  match error {
    Failure(message) => "Failure(" + message.strip_prefix("internal/driver/").unwrap_or(message[:]).to_owned() + ")"
    _ => error.to_string()
  }
}

///|
async fn run(args : ArrayView[String]) -> Int32 {
  let normalized : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      normalized.push(arg)
      value_next = false
      continue
    }
    if arg == "--" {
      options = false
    }
    if options &&
      arg.length() > 1 &&
      arg[0] == '-' &&
      arg[1:].iter().all(c => c >= '0' && c <= '9') {
      normalized.push("--width=" + arg[1:].to_owned())
    } else {
      normalized.push(arg)
    }
    if options {
      value_next = ["--width", "--goal", "--prefix"].contains(arg)
      if arg.has_prefix("-") && !arg.has_prefix("--") {
        for offset in 1..<arg.length() {
          if arg[offset] is ('w' | 'g' | 'p') {
            value_next = offset + 1 == arg.length()
            break
          }
        }
      }
    }
  }
  let parsed = @cli.parse(normalized, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("fmt \{MODULE_VERSION}\n")
    return 0
  }
  let requested_width = parsed.last_value("width")
  let mut width = @string.parse_int(requested_width.unwrap_or(DEFAULT_WIDTH))
  guard width >= 0 && width <= 2500 else {
    fail("width must be between 0 and 2500")
  }
  let goal = match parsed.last_value("goal") {
    Some(s) => @string.parse_int(s)
    None => width * 187 / 200
  }
  guard goal >= 0 && goal <= width else {
    fail("goal must be nonnegative and at most width")
  }
  if parsed.contains("goal") && requested_width is None {
    width = goal + 10
  }
  let paths = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut status = 0
  for path in paths {
    try {
      let data = if path == "-" {
        @stdio.stdin.read_all().binary()
      } else {
        @fs.read_file(path).binary()
      }
      @stdio.stdout.write(
        @reflow.format(
          data,
          width,
          goal,
          parsed.contains("split-only"),
          parsed.contains("uniform-spacing"),
          crown=parsed.contains("crown-margin"),
          tagged=parsed.contains("tagged-paragraph"),
          prefix=@bytere.argument(
            parsed.last_value("prefix").unwrap_or(DEFAULT_PREFIX),
          ),
        ),
      )
    } catch {
      err => {
        @stdio.stderr.write("fmt: \{path}: \{diagnostic(err)}\n")
        status = 1
      }
    }
  }
  status
}

///|
pub async fn run_main() -> Unit {
  let status = run(@env.args()[1:]) catch {
    @cli.CliError(message~, ..) => {
      @stdio.stderr.write("fmt: \{message}\n")
      1
    }
    err => {
      @stdio.stderr.write("fmt: \{diagnostic(err)}\n")
      1
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
