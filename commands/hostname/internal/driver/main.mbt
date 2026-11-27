///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("hostname \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("setting the hostname is unsupported")
  }
  let name = @procfs.kernel_field(Node)
  let result = if parsed.contains("short") {
    name.split(".").next().unwrap_or("").to_owned()
  } else {
    name
  }
  @stdio.stdout.text.write(result + "\n")
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("hostname: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("hostname: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("hostname: \{err}\n")
      @env.exit(1)
    }
  }
}
