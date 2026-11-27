///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("ps \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  guard parsed.values("pid") is [pid_text] &&
    !parsed.values("format").is_empty() else {
    raise Failure::Failure("select one PID with -p PID -o FIELD=")
  }
  let pid = @string.parse_uint(pid_text)
  guard pid > 0U else { raise Failure::Failure("PID must be positive") }
  guard @async.platform is Linux else {
    raise Failure::Failure("query requires Linux procfs")
  }
  match @fields.rows(pid, parsed.values("format")) {
    Some(output) => @stdio.stdout.text.write(output)
    None => @env.exit(1)
  }
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("ps: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("ps: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("ps: \{err}\n")
      @env.exit(1)
    }
  }
}
