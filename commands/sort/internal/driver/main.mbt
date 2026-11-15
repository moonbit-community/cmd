///|
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("sort \{MODULE_VERSION}\n")
    return
  }
  let parsed = parse_args(args) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("sort: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  let status = execute_sort(parsed) catch {
    @order.CliError(message) => {
      @stdio.stderr.write(message + "\n")
      2
    }
    error => {
      @stdio.stderr.write("sort: \{error}\n")
      2
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
