///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("uptime \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  guard parsed.contains("pretty") else {
    raise Failure::Failure("select -p for elapsed system uptime")
  }
  guard @async.platform is Linux else {
    raise Failure::Failure("query requires Linux procfs")
  }
  let fields = @fs.read_text("/proc/uptime").split(" ")
  let seconds = @string.parse_double(fields.next().unwrap())
  @stdio.stdout.text.write(pretty(seconds) + "\n")
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("uptime: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("uptime: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("uptime: \{err}\n")
      @env.exit(1)
    }
  }
}
