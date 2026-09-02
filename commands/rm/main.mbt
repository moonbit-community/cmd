///|
priv struct RmOptions {
  recursive : Bool
  force : Bool
  empty_directories : Bool
  verbose : Bool
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("recursive", short='r'),
    @cli.flag("recursive", short='R'),
    @cli.flag("force", short='f'),
    @cli.flag("dir", short='d'),
    @cli.flag("verbose", short='v'),
    @cli.flag("preserve-root"),
    @cli.flag("no-preserve-root"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("rm: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: rm [-f] [-r|-R] [-d] [-v] FILE...\nNote: root and current-directory protection cannot be disabled.\n",
    )
    return
  }
  if parsed.contains("no-preserve-root") {
    @stdio.stderr.write(
      "rm: --no-preserve-root is disabled by repository policy\n",
    )
    @sys.exit(1)
    return
  }
  let options : RmOptions = {
    recursive: parsed.contains("recursive"),
    force: parsed.contains("force"),
    empty_directories: parsed.contains("dir"),
    verbose: parsed.contains("verbose"),
  }
  let paths = parsed.operands
  if paths.is_empty() {
    if options.force {
      return
    }
    @stdio.stderr.write("rm: missing operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for path in paths {
    if @fsops.protects_working_directory(path) {
      @stdio.stderr.write("rm: refusing to remove protected path '\{path}'\n")
      failed = true
      continue
    }
    let kind = @fsops.kind_if_exists(path) catch {
      err => {
        @stdio.stderr.write("rm: cannot inspect '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    match kind {
      None if options.force => continue
      None => {
        @stdio.stderr.write("rm: cannot remove '\{path}': no such file\n")
        failed = true
        continue
      }
      Some(Directory) if options.recursive =>
        @fsops.remove_path(path, true) catch {
          @fsops.FsOpError(message) => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{message}\n")
            failed = true
            continue
          }
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
      Some(Directory) if options.empty_directories =>
        @fs.rmdir(path) catch {
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
      Some(Directory) => {
        @stdio.stderr.write("rm: cannot remove '\{path}': is a directory\n")
        failed = true
        continue
      }
      Some(_) =>
        @fsops.remove_path(path, false) catch {
          @fsops.FsOpError(message) => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{message}\n")
            failed = true
            continue
          }
          err => {
            @stdio.stderr.write("rm: cannot remove '\{path}': \{err}\n")
            failed = true
            continue
          }
        }
    }
    if options.verbose {
      @stdio.stdout.write("removed '\{path}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
