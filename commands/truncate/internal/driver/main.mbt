///|
async fn report(path : String, error : Error) -> Unit {
  let message = match error {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    other => other.to_string()
  }
  @stdio.stderr.text.write(
    "truncate: " + (if path == "" { "" } else { path + ": " }) + message + "\n",
  )
}

///|
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("truncate \{MODULE_VERSION}\n")
    return 0
  }
  guard !parsed.operands.is_empty() else { raise Failure("missing operand") }
  guard parsed.last_value("size") is Some(text) else {
    raise Failure("missing --size")
  }
  let size = @resize.parse(text)
  let mut status = 0
  for path in parsed.operands {
    @resize.apply(size, path, no_create=parsed.contains("no-create")) catch {
      error => {
        report(path, error)
        status = 1
      }
    }
  }
  status
}

///|
pub async fn run_main() -> Unit {
  let status = run(@env.args()[1:]) catch {
    error => {
      report("", error)
      1
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
