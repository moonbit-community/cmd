///|
/// Ignore all arguments and exit with status 0, like true(1).
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.text.write(metadata_help())
  } else if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.text.write("true \{MODULE_VERSION}\n")
  }
}
