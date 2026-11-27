///|
async fn report(path : String, error : Error) -> Unit {
  let message = match error {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    other => other.to_string()
  }
  @stdio.stderr.text.write(
    "stat: " + (if path == "" { "" } else { path + ": " }) + message + "\n",
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
    @stdio.stdout.text.write("stat \{MODULE_VERSION}\n")
    return 0
  }
  guard !parsed.operands.is_empty() else { raise Failure("missing operand") }
  guard parsed.last_value("format") is Some(text) else {
    raise Failure("choose --format for the supported stat fields")
  }
  let fields = @format.parse(text)
  let mut status = 0
  for path in parsed.operands {
    let line = @format.render(
      fields,
      path,
      follow=parsed.contains("dereference"),
    ) catch {
      error => {
        report(path, error)
        status = 1
        continue
      }
    }
    @stdio.stdout.text.write(line + "\n")
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
