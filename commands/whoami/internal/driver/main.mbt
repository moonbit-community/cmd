///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("whoami \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  let cred = @procfs.credentials()
  let names = @procfs.local_names(Passwd, [cred.effective_uid])
  @stdio.stdout.text.write(names.join(" ") + "\n")
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("whoami: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("whoami: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("whoami: \{err}\n")
      @env.exit(1)
    }
  }
}
