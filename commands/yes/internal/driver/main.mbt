///|
fn output_line(args : ArrayView[String]) -> String {
  if args.is_empty() {
    "y\n"
  } else {
    args.join(" ") + "\n"
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("yes \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  if args.length() == 1 && args[0] == "--help" {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if args.length() == 1 && args[0] == "--version" {
    @stdio.stdout.text.write("yes \{MODULE_VERSION}\n")
    return
  }
  let line = output_line(args)
  for ;; {
    @stdio.stdout.text.write(line) catch {
      // A closed downstream pipe ends the producer.
      _ => return
    }
  }
}
