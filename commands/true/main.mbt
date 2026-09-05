///|
/// Ignore all arguments and exit with status 0, like true(1).
async fn main {
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write("Usage: true [ignored command line arguments]\n")
  } else if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("true (moonbit cmd) 0.1.3\n")
  }
}
