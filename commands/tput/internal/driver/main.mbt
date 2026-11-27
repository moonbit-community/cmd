///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("tput \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands is [name, .. args] else {
    raise @terminal.TerminalError(2, "capability is required")
  }
  let selected = parsed.last_value("terminal")
  let entry = @terminal.lookup(selected)
  @stdio.stdout.write(
    @terminal.capability(entry, name, args, selected is Some(_)),
  )
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @terminal.TerminalError(code, message) => {
      if !message.is_empty() {
        @stdio.stderr.text.write("tput: \{message}\n")
      }
      @env.exit(code)
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("tput: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("tput: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("tput: \{err}\n")
      @env.exit(1)
    }
  }
}
