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
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [@cli.flag("help"), @cli.flag("version")]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("unlink: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: unlink FILE...\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("unlink (moonbit cmd) \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write("unlink: missing operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for path in parsed.operands {
    unlink_one(path) catch {
      UnlinkError(message) => {
        @stdio.stderr.write("unlink: \{message}\n")
        failed = true
        continue
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
