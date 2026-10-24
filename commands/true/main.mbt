///|
/// Ignore all arguments and exit with status 0, like true(1).
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: true [ignored command line arguments]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
  } else if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("true \{command_version}\n")
  }
}
