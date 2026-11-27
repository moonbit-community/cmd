///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("tty \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  @terminal.require_redirected(0)
  if !parsed.contains("silent") {
    @stdio.stdout.text.write("not a tty\n")
  }
  @env.exit(1)
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @terminal.TerminalError(code, message) => {
      if !message.is_empty() {
        @stdio.stderr.text.write("tty: \{message}\n")
      }
      @env.exit(code)
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("tty: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("tty: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("tty: \{err}\n")
      @env.exit(1)
    }
  }
}
