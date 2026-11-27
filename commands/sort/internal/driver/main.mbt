///|
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.text.write("sort \{MODULE_VERSION}\n")
    return
  }
  let parsed = parse_args(args) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("sort: \{message}: '\{option}'\n")
      @env.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  let status = execute_sort(parsed) catch {
    @order.CliError(message) => {
      @stdio.stderr.text.write(message + "\n")
      2
    }
    error => {
      @stdio.stderr.text.write("sort: \{@stream.transport_cause(error)}\n")
      2
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
