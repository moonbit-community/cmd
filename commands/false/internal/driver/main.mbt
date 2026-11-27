///|
/// Ignore all arguments and exit with status 1, like false(1).
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.text.write("false \{MODULE_VERSION}\n")
    return
  }
  @env.exit(1)
}
