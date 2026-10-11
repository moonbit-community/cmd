///|
async fn run(args : ArrayView[String]) -> Int {
  let normalized : Array[String] = []
  let mut options = true
  for arg in args {
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
  }
  let parsed = @cli.parse(normalized, [
    @cli.option("width", short='w'),
    @cli.option("goal", short='g'),
    @cli.flag("split-only", short='s'),
    @cli.flag("uniform-spacing", short='u'),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: fmt [-WIDTH] [-w WIDTH] [-g GOAL] [-su] [FILE...]\nReformat paragraphs, preserving indentation; default width 75.\n-s splits lines without joining; -u uses uniform spacing.\nC-locale byte columns. Crown/tagged margins and prefixes are not supported.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("fmt 0.1.0\n")
    return 0
  }
  let requested_width = parsed.last_value("width")
  let mut width = @string.parse_int(requested_width.unwrap_or("75"))
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
        format(
          data,
          width,
          goal,
          parsed.contains("split-only"),
          parsed.contains("uniform-spacing"),
        ),
      )
    } catch {
      err => {
        @stdio.stderr.write("fmt: \{path}: \{err}\n")
        status = 1
      }
    }
  }
  status
}

///|
async fn main {
  let status = run(@env.args()[1:]) catch {
    @cli.CliError(message~, ..) => {
      @stdio.stderr.write("fmt: \{message}\n")
      1
    }
    err => {
      @stdio.stderr.write("fmt: \{err}\n")
      1
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
