///|
fn output_line(args : ArrayView[String]) -> String {
  if args.is_empty() {
    "y\n"
  } else {
    args.join(" ") + "\n"
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("yes 0.1.3\n")
    return
  }
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write(
      "Usage: yes [STRING]...\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("yes \{command_version}\n")
    return
  }
  let line = output_line(args)
  for ;; {
    @stdio.stdout.write(line) catch {
      // A closed pipe (for example `yes | head`) ends the producer. Cancellation
      // remains visible under async 0.22.4's cancellation semantics.
      _ => return
    }
  }
}
