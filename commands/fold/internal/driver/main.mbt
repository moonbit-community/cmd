///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("fold \{MODULE_VERSION}\n")
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
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("fold: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("fold \{MODULE_VERSION}\n")
    return
  }
  let width = @string.parse_int(
    parsed.last_value("width").unwrap_or(DEFAULT_WIDTH),
  ) catch {
    _ => 0
  }
  if width <= 0 || width > 2147483638 {
    @stdio.stderr.write("fold: invalid number of columns\n")
    @env.exit(1)
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
    @env.exit(1)
  }
}
