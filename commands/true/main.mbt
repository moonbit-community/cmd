///|
/// Ignore all arguments and exit with status 0, like true(1).
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("true 0.2.2\n")
    return
  }
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: true [ignored command line arguments]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
  } else if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("true \{command_version}\n")
  }
}
