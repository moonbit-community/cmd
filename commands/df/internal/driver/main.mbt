///|
async fn run(args : ArrayView[String]) -> Unit {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("df \{MODULE_VERSION}\n")
    return
  }
  guard parsed.last_value("output") is Some(text) else {
    raise Failure(
      "capacity fields are unavailable; select --output=source,fstype,target",
    )
  }
  guard !parsed.operands.is_empty() else {
    raise Failure("supply a path to select its mount")
  }
  @stdio.stdout.text.write(
    @mounts.table(@mounts.columns(text), parsed.operands),
  )
}

///|
pub async fn run_main() -> Unit {
  let message = try run(@env.args()[1:]) catch {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    error => error.to_string()
  } noraise {
    _ => return
  }
  @stdio.stderr.text.write("df: " + message + "\n")
  @env.exit(1)
}
