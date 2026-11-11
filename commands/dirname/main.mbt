///|
let command : @argparse.Command = @argparse.Command(
  "dirname",
  flags=[@argparse.FlagArg("zero", short='z'), @argparse.FlagArg("help")],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
fn chars_string(chars : Array[Char], end : Int32) -> String {
  let out = StringBuilder()
  for i in 0..<end {
    out.write_char(chars[i])
  }
  out.to_string()
}

///|
fn dir_name(path : String) -> String {
  if path is "" {
    return "."
  }
  let chars : Array[Char] = path.iter().collect()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  if end == 1 && chars[0] == '/' {
    return "/"
  }
  while end > 0 && chars[end - 1] != '/' {
    end -= 1
  }
  if end == 0 {
    return "."
  }
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  chars_string(chars, end)
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("dirname \{MODULE_VERSION}\n")
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
            ["zero", "help"].contains(name) {
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
      @stdio.stderr.write("dirname: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: dirname [-z] NAME...\n      --help      display this help and exit\n      --version   display version and exit\nOrdinary option/operand errors exit 1; documented capability refusals retain their own status.\n",
    )
    return
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  let zero = parsed.flags.contains("zero")
  if operands.is_empty() {
    @stdio.stderr.write("dirname: missing operand\n")
    @sys.exit(1)
    return
  }
  let separator = if zero { "\u0000" } else { "\n" }
  for path in operands {
    @stdio.stdout.write(dir_name(path) + separator)
  }
}
