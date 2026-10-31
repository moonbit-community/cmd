///|
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("sort 0.2.5\n")
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
    @stdio.stdout.write(
      "Usage: sort [-bcdfghinMruVz] [-s] [-m] [-o FILE] [-R|--sort=random] [--random-source=FILE] [-k KEY] [-t CHAR] [-c|-C] [-S SIZE] [-T DIR] [--batch-size=N] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\n\nLarge inputs use temporary disk runs and require filesystem write access.\n-S/--buffer-size selects an accounted byte budget (default units: KiB).\n-T/--temporary-directory may repeat; --batch-size uses at most 16 merge inputs.\nNonzero percentage buffer sizes require an unavailable physical-memory query.\n",
    )
    return
  }
  let status = execute_sort(parsed) catch {
    CliError(message) => {
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
