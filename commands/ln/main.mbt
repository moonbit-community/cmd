///|
priv struct LnOptions {
  force : Bool
  interactive : Bool
  no_target_directory : Bool
  no_dereference_target : Bool
  relative : Bool
  verbose : Bool
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
fn relative_target(target : String, link_path : String) -> String {
  let target_path = @path.Path(target).resolve()
  let link_dir = @path.Path(@fsops.dirname(link_path)).resolve()
  target_path.relative(base=link_dir).to_string()
}

///|
async fn confirm_overwrite(path : String) -> Bool {
  @stdio.stderr.write("ln: replace '\{path}'? ")
  match @stdio.stdin.read_until("\n") {
    Some(answer) => answer.has_prefix("y") || answer.has_prefix("Y")
    None => false
  }
}

///|
async fn create_symlink(
  link_path : String,
  target : String,
  backup_path : String?,
) -> Unit {
  errdefer (match backup_path {
    Some(backup) => @fsops.restore_backup(link_path, backup) catch { _ => () }
    None => ()
  })
  @fs.symlink(link_path, target~)
}

///|
async fn create_link(
  target : String,
  link_path : String,
  options : LnOptions,
) -> Bool {
  let existing = @fsops.kind_if_exists(link_path)
  if existing == Some(Directory) {
    raise @fsops.FsOpError("refusing to replace directory: '\{link_path}'")
  }
  let mut backup_path : String? = None
  if existing is Some(_) {
    if options.interactive {
      if !confirm_overwrite(link_path) {
        return false
      }
    }
    let backup = @fsops.backup_destination(
      link_path,
      options.backup,
      suffix=options.suffix,
    )
    backup_path = backup
    if backup is None && !options.force && !options.interactive {
      raise @fsops.FsOpError("destination exists: '\{link_path}'")
    }
    if backup is None {
      @fsops.remove_path(link_path, false)
    }
  }
  let actual_target = if options.relative {
    relative_target(target, link_path)
  } else {
    target
  }
  create_symlink(link_path, actual_target, backup_path)
  if options.verbose {
    @stdio.stdout.write("'\{link_path}' -> '\{actual_target}'\n")
  }
  true
}

///|
async fn main {
  let parsed = @cli.parse(normalized_args(@env.args()[1:]), [
    @cli.flag("symbolic", short='s'),
    @cli.flag("force", short='f'),
    @cli.flag("interactive", short='i'),
    @cli.flag("relative", short='r'),
    @cli.flag("no-dereference-target", short='n'),
    @cli.flag("no-target-directory", short='T'),
    @cli.option("target-directory", short='t'),
    @cli.flag("backup", short='b'),
    @cli.option("backup-control"),
    @cli.option("suffix", short='S'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("ln: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: ln -s [-f|-i] [-r] [-n|-T] [-t DIRECTORY] [-b|--backup[=CONTROL]] [-S SUFFIX] TARGET... LINK_NAME\n",
    )
    return
  }
  if !parsed.contains("symbolic") {
    @stdio.stderr.write(
      "ln: hard links are unavailable in the portable filesystem API; use -s\n",
    )
    @sys.exit(1)
    return
  }
  if !@platform.symbolic_link_creation_supported() {
    @stdio.stderr.write("ln: unsupported capability: symbolic links\n")
    @sys.exit(1)
    return
  }
  let operands = parsed.operands
  let target_directory = parsed.last_value("target-directory")
  let backup_text = match parsed.last_occurrence(["backup", "backup-control"]) {
    Some("backup") => "existing"
    Some("backup-control") => parsed.last_value("backup-control").unwrap()
    _ => "none"
  }
  let options : LnOptions = {
    force: parsed.contains("force"),
    interactive: parsed.contains("interactive"),
    no_target_directory: parsed.contains("no-target-directory"),
    no_dereference_target: parsed.contains("no-dereference-target"),
    relative: parsed.contains("relative"),
    verbose: parsed.contains("verbose"),
    backup: @fsops.parse_backup_control(backup_text) catch {
      @fsops.FsOpError(message) => {
        @stdio.stderr.write("ln: \{message}\n")
        @sys.exit(2)
        return
      }
    },
    suffix: parsed.last_value("suffix").unwrap_or("~"),
  }
  let (targets, destination) = match target_directory {
    Some(directory) => {
      if operands.is_empty() {
        @stdio.stderr.write("ln: missing operand\n")
        @sys.exit(1)
        return
      }
      if options.no_target_directory {
        @stdio.stderr.write("ln: -t cannot be combined with -T\n")
        @sys.exit(1)
        return
      }
      (operands, Some(directory))
    }
    None => {
      if operands.length() < 2 {
        @stdio.stderr.write("ln: missing operand\n")
        @sys.exit(1)
        return
      }
      (
        operands[0:operands.length() - 1].to_owned(),
        Some(operands[operands.length() - 1]),
      )
    }
  }
  guard destination is Some(destination) else { return }
  let destination_lstat = @fsops.kind_if_exists(destination) catch {
    err => {
      @stdio.stderr.write("ln: cannot inspect '\{destination}': \{err}\n")
      @sys.exit(1)
      return
    }
  }
  let destination_is_directory = if options.no_target_directory {
    false
  } else if options.no_dereference_target && destination_lstat == Some(SymLink) {
    false
  } else {
    (@fs.kind(destination) catch { _ => Unknown }) == Directory
  }
  if target_directory is Some(_) && !destination_is_directory {
    @stdio.stderr.write(
      "ln: target directory is not a directory: '\{destination}'\n",
    )
    @sys.exit(1)
    return
  }
  if target_directory is None &&
    targets.length() > 1 &&
    !destination_is_directory {
    @stdio.stderr.write("ln: target is not a directory: '\{destination}'\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for target in targets {
    let link_path = if destination_is_directory {
      @fsops.join(destination, @fsops.basename(target))
    } else {
      destination
    }
    ignore(
      create_link(target, link_path, options) catch {
        @fsops.FsOpError(message) => {
          @stdio.stderr.write(
            "ln: failed to create '\{link_path}': \{message}\n",
          )
          failed = true
          continue
        }
        err => {
          @stdio.stderr.write("ln: failed to create '\{link_path}': \{err}\n")
          failed = true
          continue
        }
      },
    )
  }
  if failed {
    @sys.exit(1)
  }
}
