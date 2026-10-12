///|
/// Ignore all arguments and exit with status 1, like false(1).
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: false [ignored command line arguments]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("false \{command_version}\n")
    return
  }
  @sys.exit(1)
}
