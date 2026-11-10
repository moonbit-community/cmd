///|
let command : @argparse.Command = @argparse.Command(
  "unlink",
  flags=[@argparse.FlagArg("help"), @argparse.FlagArg("version")],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
priv suberror UnlinkError {
  UnlinkError(String)
}

///|
fn reject_directory(path : String) -> Unit raise UnlinkError {
  raise UnlinkError("cannot unlink '\{path}': is a directory")
}

///|
async fn unlink_one(path : String) -> Unit raise UnlinkError {
  let kind = @fs.kind(path, follow_symlink=false) catch {
    err => raise UnlinkError("cannot unlink '\{path}': \{err}")
  }
  match kind {
    Directory => reject_directory(path)
    _ =>
      @fs.remove(path) catch {
        err => raise UnlinkError("cannot unlink '\{path}': \{err}")
      }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("unlink \{MODULE_VERSION}\n")
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
            ["help", "version"].contains(name) {
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
      @stdio.stderr.write("unlink: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(
      "Usage: unlink FILE\nRemove exactly one non-directory name.\n      --help     display this help and exit\n      --version  display version and exit\n",
    )
    return
  }
  if parsed.flags.contains("version") {
    @stdio.stdout.write("unlink \{MODULE_VERSION}\n")
    return
  }
  if operands.is_empty() {
    @stdio.stderr.write("unlink: missing operand\n")
    @sys.exit(1)
    return
  }
  if operands.length() != 1 {
    @stdio.stderr.write("unlink: extra operand '\{operands[1]}'\n")
    @sys.exit(1)
    return
  }
  unlink_one(operands[0]) catch {
    UnlinkError(message) => {
      @stdio.stderr.write("unlink: \{message}\n")
      @sys.exit(1)
    }
  }
}
