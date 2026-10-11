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
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.write("Usage: yes [STRING]...\n")
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.write("yes (moonbit cmd) \{command_version}\n")
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
