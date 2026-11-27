///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("expr \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:].to_owned()
  if args == ["--help"] {
    @stdio.stdout.write(metadata_help())
    return
  }
  if args == ["--version"] {
    @stdio.stdout.write("expr \{MODULE_VERSION}\n")
    return
  }
  if args.get(0) == Some("--") {
    ignore(args.remove(0))
  }
  let value = @expression.evaluate(args.map(@bytere.argument)) catch {
    @expression.EvalError(message) | @bytere.PatternError(message) => {
      @stdio.stderr.write("expr: \{message}\n")
      @env.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("expr: \{err}\n")
      @env.exit(2)
      return
    }
  }
  @stdio.stdout.write(@bytere.bytes(value + "\n"))
  if !@expression.truth(value) {
    @env.exit(1)
  }
}
