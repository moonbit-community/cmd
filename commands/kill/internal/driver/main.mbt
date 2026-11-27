///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("kill \{MODULE_VERSION}\n")
    return
  }
  guard parsed.contains("list") && parsed.operands is [input] else {
    raise Failure::Failure("signal delivery is unavailable; use -l SIGNAL")
  }
  guard !(@async.platform is Windows) else {
    raise Failure::Failure("POSIX signal lookup is unavailable on Windows")
  }
  let lookup = input
    .to_upper()
    .strip_prefix("SIG")
    .unwrap_or(input.to_upper()[:])
  for
    (name, signal) in [
      ("HUP", @signal.SIGHUP),
      ("INT", SIGINT),
      ("TERM", SIGTERM),
    ] {
    let number = signal.to_int().to_string()
    if lookup == name[:] || input == number {
      @stdio.stdout.text.write(
        (if input == number { name } else { number }) + "\n",
      )
      return
    }
  }
  raise Failure::Failure("unsupported signal: " + input)
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("kill: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("kill: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("kill: \{err}\n")
      @env.exit(1)
    }
  }
}
