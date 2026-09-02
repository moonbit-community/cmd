///|
priv struct MvOptions {
  mut no_clobber : Bool
  no_target_directory : Bool
  verbose : Bool
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
    @cli.flag("no-target-directory", short='T'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("mv: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: mv [-f|-n] [-T] [-v] SOURCE... DEST\nNote: cross-filesystem fallback is unavailable; a failed rename leaves SOURCE intact.\n",
    )
    return
  }
  let operands = parsed.operands
  let options : MvOptions = {
    no_clobber: parsed.contains("no-clobber"),
    no_target_directory: parsed.contains("no-target-directory"),
    verbose: parsed.contains("verbose"),
  }
  if parsed.last_occurrence(["force", "no-clobber"]) == Some("force") {
    options.no_clobber = false
  }
  if operands.length() < 2 {
    @stdio.stderr.write("mv: missing source or destination operand\n")
    @sys.exit(1)
    return
  }
  let destination = operands[operands.length() - 1]
  let sources = operands[0:operands.length() - 1]
  if options.no_target_directory && sources.length() > 1 {
    @stdio.stderr.write("mv: -T cannot be used with multiple sources\n")
    @sys.exit(1)
    return
  }
  let destination_kind = @fsops.kind_if_exists(destination) catch {
    err => {
      @stdio.stderr.write("mv: cannot inspect '\{destination}': \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if sources.length() > 1 && destination_kind != Some(Directory) {
    @stdio.stderr.write(
      "mv: destination is not a directory: '\{destination}'\n",
    )
    @sys.exit(1)
    return
  }
  let mut failed = false
  for source in sources {
    let target = if sources.length() > 1 ||
      (!options.no_target_directory && destination_kind == Some(Directory)) {
      @fsops.join(destination, @fsops.basename(source))
    } else {
      destination
    }
    let target_kind = @fsops.kind_if_exists(target) catch {
      err => {
        @stdio.stderr.write("mv: cannot inspect '\{target}': \{err}\n")
        failed = true
        continue
      }
    }
    if options.no_clobber && target_kind is Some(_) {
      continue
    }
    let source_kind = @fs.kind(source, follow_symlink=false) catch {
      err => {
        @stdio.stderr.write("mv: cannot access '\{source}': \{err}\n")
        failed = true
        continue
      }
    }
    if source_kind == Directory {
      @fsops.ensure_not_nested_destination(source, target) catch {
        @fsops.FsOpError(message) => {
          @stdio.stderr.write(
            "mv: cannot move '\{source}' to '\{target}': \{message}\n",
          )
          failed = true
          continue
        }
        err => {
          @stdio.stderr.write(
            "mv: cannot move '\{source}' to '\{target}': \{err}\n",
          )
          failed = true
          continue
        }
      }
    }
    @fs.rename(source, target, replace=true) catch {
      err => {
        @stdio.stderr.write(
          "mv: cannot move '\{source}' to '\{target}': \{err}\n",
        )
        failed = true
        continue
      }
    }
    if options.verbose {
      @stdio.stdout.write("renamed '\{source}' -> '\{target}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
