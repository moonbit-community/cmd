///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("printf \{MODULE_VERSION}\n")
    return
  }
  let argv = @env.args()[1:]
  if argv.length() > 0 && argv[0] == "--help" {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let operands = if argv.length() > 0 && argv[0] == "--" {
    argv[1:]
  } else {
    argv
  }
  if operands.is_empty() {
    @stdio.stderr.write(
      "printf: missing operand\nTry 'printf --help' for more information.\n",
    )
    @sys.exit(1)
    return
  }
  let format = operands[0]
  let ctx = @format.render(format, operands[1:].to_owned())
  @stdio.stdout.write(ctx.out)
  for msg in ctx.messages {
    @stdio.stderr.write(msg + "\n")
  }
  match ctx.fatal {
    Some(msg) => {
      @stdio.stderr.write(msg + "\n")
      @sys.exit(1)
      return
    }
    None => ()
  }
  if ctx.exit_error {
    @sys.exit(1)
  }
}
