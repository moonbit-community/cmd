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
    @stdio.stdout.write("unlink 0.1.5\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [@cli.flag("help"), @cli.flag("version")]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("unlink: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: unlink FILE\nRemove exactly one non-directory name.\n      --help     display this help and exit\n      --version  display version and exit\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("unlink \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write("unlink: missing operand\n")
    @sys.exit(1)
    return
  }
  if parsed.operands.length() != 1 {
    @stdio.stderr.write("unlink: extra operand '\{parsed.operands[1]}'\n")
    @sys.exit(1)
    return
  }
  unlink_one(parsed.operands[0]) catch {
    UnlinkError(message) => {
      @stdio.stderr.write("unlink: \{message}\n")
      @sys.exit(1)
    }
  }
}
