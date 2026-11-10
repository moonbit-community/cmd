///|
let command : @argparse.Command = @argparse.Command(
  "printenv",
  flags=[@argparse.FlagArg("null", short='0'), @argparse.FlagArg("help")],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("printenv \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = command.parse(argv=args, env=Map([])) catch {
    error => {
      let text = error.to_string()
      let line = match text.rev_find("' found") {
        Some(end) => text[:end + 7]
        None => text.split("\n").next().unwrap_or(text[:])
      }
      let (message, option) = match line {
        [.. "error: unexpected argument '--", .. rest] => {
          let spelling = rest.strip_suffix("' found").unwrap_or(rest)
          let name = spelling.split("=").next().unwrap_or(spelling).to_owned()
          let message = if spelling.contains("=") &&
            ["null", "help"].contains(name) {
            "flag does not accept a value"
          } else {
            "unknown option"
          }
          (message, name)
        }
        [.. "error: unexpected argument '-", .. rest] =>
          (
            "unknown short option",
            rest.strip_suffix("' found").unwrap_or(rest).to_owned(),
          )
        _ => (text, "")
      }
      @stdio.stderr.write("printenv: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: printenv [-0] [NAME...]\n      --help      display this help and exit\n      --version   display version and exit\n",
    )
    return
  }
  let names = operands
  let zero = parsed.flags.contains("null")
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
