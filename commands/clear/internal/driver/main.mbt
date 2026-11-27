///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("clear \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  let entry = @terminal.lookup(parsed.last_value("terminal"))
  @stdio.stdout.write(
    @terminal.clear(entry, parsed.contains("keep-scrollback")),
  )
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @terminal.TerminalError(code, message) => {
      if !message.is_empty() {
        @stdio.stderr.text.write("clear: \{message}\n")
      }
      @env.exit(code)
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("clear: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("clear: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("clear: \{err}\n")
      @env.exit(1)
    }
  }
}
