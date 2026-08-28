///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("null", short='0'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("printenv: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: printenv [-0] [NAME...]\n")
    return
  }
  let names = parsed.operands
  let zero = parsed.contains("null")
  let separator = if zero { "\u0000" } else { "\n" }
  let environment = @env.get_env_vars()
  let mut missing = false
  if names.is_empty() {
    for name, value in environment {
      @stdio.stdout.write("\{name}=\{value}\{separator}")
    }
  } else {
    for name in names {
      match environment.get(name) {
        Some(value) => @stdio.stdout.write(value + separator)
        None => missing = true
      }
    }
  }
  if missing {
    @sys.exit(1)
  }
}
