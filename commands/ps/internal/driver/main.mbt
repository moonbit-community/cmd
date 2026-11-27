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
    parsed.values("format") is ["comm="] else {
    raise Failure::Failure("select one PID with -p PID -o comm=")
  }
  let pid = @string.parse_uint(pid_text)
  guard pid > 0U else { raise Failure::Failure("PID must be positive") }
  guard @async.platform is Linux else {
    raise Failure::Failure("query requires Linux procfs")
  }
  let comm = @fs.read_text("/proc/" + pid.to_string() + "/comm") catch {
    @os_error.OsError(NotFound, ..) => @env.exit(1)
    err => raise err
  }
  guard comm.strip_suffix("\n") is Some(name) &&
    name.iter().all(ch => ch >= ' ' && ch <= '~') else {
    raise Failure::Failure(
      "process name is outside the printable ASCII profile",
    )
  }
  @stdio.stdout.text.write(comm)
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
