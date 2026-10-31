///|
async fn run(args : ArrayView[String]) -> Int32 {
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
    @cli.flag("crown-margin", short='c'),
    @cli.flag("tagged-paragraph", short='t'),
    @cli.option("prefix", short='p'),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: fmt [-WIDTH] [-w WIDTH] [-g GOAL] [-suct] [-p PREFIX] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\nReformat paragraphs, preserving indentation; default width 75.\n-s splits lines without joining; -u uses uniform spacing.\n-c, --crown-margin allows a different first-line indent.\n-t, --tagged-paragraph preserves a hanging indent.\n-p, --prefix=PREFIX reformats only matching prefixed lines.\nC-locale byte columns; split takes precedence over crown, then tagged.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("fmt 0.1.4\n")
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
          crown=parsed.contains("crown-margin"),
          tagged=parsed.contains("tagged-paragraph"),
          prefix=@bytere.argument(parsed.last_value("prefix").unwrap_or("")),
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
