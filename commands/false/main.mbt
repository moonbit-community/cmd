///|
/// Ignore all arguments and exit with status 1, like false(1).
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write("Usage: false [ignored command line arguments]\n")
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("false (moonbit cmd) \{command_version}\n")
    return
  }
  @sys.exit(1)
}
