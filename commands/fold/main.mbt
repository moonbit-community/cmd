///|
fn help_message() -> String {
  let message =
    #|Usage: fold [OPTION]... [FILE]...
    #|Wrap each input line, reading stdin with no FILE or FILE -.
    #|  -b, --bytes          count bytes rather than columns
    #|  -c, --characters     count characters in the C-locale byte profile
    #|  -s, --spaces         break after the last available blank
    #|  -w, --width=WIDTH    use WIDTH columns instead of 80
    #|      --help           display this help and exit
    #|      --version        display version and exit
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("fold 0.1.2\n")
    return
  }
  let args : Array[String] = []
  let mut operands_only = false
  for arg in @env.args()[1:] {
    if arg == "--" {
      operands_only = true
    }
    if !operands_only &&
      arg.length() > 1 &&
      arg[0] == '-' &&
      arg[1] is ('0'..<='9') {
      args.push("--width=" + arg[1:].to_owned())
    } else {
      args.push(arg)
    }
  }
  let parsed = @cli.parse(args, [
    @cli.flag("bytes", short='b', repeatable=true),
    @cli.flag("characters", short='c', repeatable=true),
    @cli.flag("spaces", short='s', repeatable=true),
    @cli.option("width", short='w', repeatable=true),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("fold: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("fold \{command_version}\n")
    return
  }
  let width = @string.parse_int(parsed.last_value("width").unwrap_or("80")) catch {
    _ => 0
  }
  if width <= 0 || width > 2147483638 {
    @stdio.stderr.write("fold: invalid number of columns\n")
    @sys.exit(1)
    return
  }
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mode = parsed.last_occurrence(["bytes", "characters"])
  let mut failed = false
  for path in sources {
    let state = FoldState::new(
      width,
      mode == Some("bytes"),
      mode == Some("characters"),
      parsed.contains("spaces"),
    )
    try {
      if path == "-" {
        fold_stream(@stdio.stdin, state)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        fold_stream(file, state)
      }
    } catch {
      err => {
        @stdio.stderr.write("fold: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
