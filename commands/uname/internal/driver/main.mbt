///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("uname \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  let fields : Array[String] = []
  if @async.platform is Windows {
    raise Failure::Failure("kernel name is unavailable on Windows")
  }
  for
    (opt, field) in [
      ("kernel-name", @procfs.System),
      ("nodename", Node),
      ("kernel-release", Release),
      ("kernel-version", Version),
    ] {
    if parsed.contains(opt) || (parsed.order.is_empty() && opt == "kernel-name") {
      fields.push(
        if @async.platform is MacOS && opt == "kernel-name" {
          "Darwin"
        } else {
          @procfs.kernel_field(field)
        },
      )
    }
  }
  @stdio.stdout.text.write(fields.join(" ") + "\n")
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("uname: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("uname: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("uname: \{err}\n")
      @env.exit(1)
    }
  }
}
