///|
priv struct MvOptions {
  no_clobber : Bool
  interactive : Bool
  no_target_directory : Bool
  verbose : Bool
  update : @fsops.UpdateMode
  backup : @fsops.BackupControl
  suffix : String
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
      result.push(arg)
    } else if options && arg == "--update" {
      result.push("--update-mode=older")
    } else if options && arg.has_prefix("--update=") {
      result.push("--update-mode=" + arg[9:].to_owned())
    } else if options && arg == "--backup" {
      result.push("--backup-control=existing")
    } else if options && arg.has_prefix("--backup=") {
      result.push("--backup-control=" + arg[9:].to_owned())
    } else {
      result.push(arg)
    }
  }
  result
}

///|
async fn confirm_overwrite(target : String) -> Bool {
  @stdio.stderr.write("mv: overwrite '\{target}'? ")
  match @stdio.stdin.read_until("\n") {
    Some(answer) => answer.has_prefix("y") || answer.has_prefix("Y")
    None => false
  }
}

///|
async fn move_one(
  source : String,
  target : String,
  options : MvOptions,
) -> Bool {
  let source_kind = @fs.kind(source, follow_symlink=false)
  if source_kind == Directory {
    @fsops.ensure_not_nested_destination(source, target)
  }
  let target_kind = @fsops.kind_if_exists(target)
  if options.no_clobber && target_kind is Some(_) {
    return false
  }
  if target_kind is Some(_) && target_kind != Some(Directory) {
    let source_time = @fsops.read_file_timestamp(source, ModificationTime)
    let target_time = @fsops.read_file_timestamp(
      target,
      ModificationTime,
      follow_symlink=false,
    )
    match
      @fsops.overwrite_decision(options.update, source_time, Some(target_time)) {
      SkipDestination => return false
      RejectDestination =>
        raise @fsops.FsOpError("destination exists under update=none-fail")
      ReplaceDestination => ()
    }
    if options.interactive {
      if !confirm_overwrite(target) {
        return false
      }
    }
  }
  let backup = if target_kind is Some(_) && target_kind != Some(Directory) {
    @fsops.backup_destination(target, options.backup, suffix=options.suffix)
  } else {
    None
  }
  let backup_to_restore = backup
  errdefer (match backup_to_restore {
    Some(path) => @fsops.restore_backup(target, path) catch { _ => () }
    None => ()
  })
  @fs.rename(source, target, replace=backup is None)
  true
}

///|
async fn main {
  let parsed = @cli.parse(normalized_args(@env.args()[1:]), [
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
    @cli.flag("interactive", short='i'),
    @cli.flag("update", short='u'),
    @cli.option("update-mode"),
    @cli.flag("backup", short='b'),
    @cli.option("backup-control"),
    @cli.option("suffix", short='S'),
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
      "Usage: mv [-f|-i|-n] [-u|--update=MODE] [-b|--backup[=CONTROL]] [-S SUFFIX] [-T] [-v] SOURCE... DEST\n",
    )
    return
  }
  let operands = parsed.operands
  if operands.length() < 2 {
    @stdio.stderr.write("mv: missing source or destination operand\n")
    @sys.exit(1)
    return
  }
  let update_text = match parsed.last_occurrence(["update", "update-mode"]) {
    Some("update") => "older"
    Some("update-mode") => parsed.last_value("update-mode").unwrap()
    _ => "all"
  }
  let update = @fsops.parse_update_mode(update_text) catch {
    @fsops.FsOpError(message) => {
      @stdio.stderr.write("mv: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let backup_text = match parsed.last_occurrence(["backup", "backup-control"]) {
    Some("backup") => "existing"
    Some("backup-control") => parsed.last_value("backup-control").unwrap()
    _ => "none"
  }
  let backup = @fsops.parse_backup_control(backup_text) catch {
    @fsops.FsOpError(message) => {
      @stdio.stderr.write("mv: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let options : MvOptions = {
    no_clobber: parsed.last_occurrence(["force", "interactive", "no-clobber"]) ==
    Some("no-clobber"),
    interactive: parsed.last_occurrence(["force", "interactive", "no-clobber"]) ==
    Some("interactive"),
    no_target_directory: parsed.contains("no-target-directory"),
    verbose: parsed.contains("verbose"),
    update,
    backup,
    suffix: parsed.last_value("suffix").unwrap_or("~"),
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
    let moved = move_one(source, target, options) catch {
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
    if moved && options.verbose {
      @stdio.stdout.write("renamed '\{source}' -> '\{target}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
