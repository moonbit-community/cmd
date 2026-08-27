///|
async fn main {
  let args = @env.args()[1:]
  let names : Array[String] = []
  let mut zero = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-0" || arg == "--null") {
      zero = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: printenv [-0] [NAME...]\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("printenv: invalid option: '\{arg}'\n")
      @sys.exit(2)
      return
    } else {
      names.push(arg)
    }
  }
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
