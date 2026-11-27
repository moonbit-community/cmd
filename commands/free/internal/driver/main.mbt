///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("free \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  guard @async.platform is Linux else {
    raise Failure::Failure("query requires Linux procfs")
  }
  let unit = match parsed.last_occurrence(["bytes", "kibi", "mebi", "gibi"]) {
    Some("bytes") => 1L
    Some("mebi") => 1048576L
    Some("gibi") => 1073741824L
    _ => 1024L
  }
  @stdio.stdout.text.write(
    report(
      @fs.read_text("/proc/meminfo"),
      unit,
      parsed.contains("wide"),
      parsed.contains("total"),
    ),
  )
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("free: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("free: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("free: \{err}\n")
      @env.exit(1)
    }
  }
}
