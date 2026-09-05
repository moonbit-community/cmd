///|
priv struct CpOptions {
  recursive : Bool
  no_clobber : Bool
  interactive : Bool
  no_target_directory : Bool
  verbose : Bool
  traversal : @fsops.LinkTraversal
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
    } else if options && arg.has_prefix("--preserve=") {
      result.push("--preserve")
    } else {
      result.push(arg)
    }
  }
  result
}

///|
async fn confirm_overwrite(target : String) -> Bool {
  @stdio.stderr.write("cp: overwrite '\{target}'? ")
  match @stdio.stdin.read_until("\n") {
    Some(answer) => answer.has_prefix("y") || answer.has_prefix("Y")
    None => false
  }
}

///|
async fn replacement_decision(
  source : String,
  target : String,
  options : CpOptions,
) -> @fsops.OverwriteDecision {
  guard @fsops.kind_if_exists(target) is Some(target_kind) else {
    return ReplaceDestination
  }
  if options.no_clobber {
    return SkipDestination
  }
  if target_kind == Directory {
    return ReplaceDestination
  }
  let source_time = @fsops.read_file_timestamp(source, ModificationTime)
  let destination_time = @fsops.read_file_timestamp(
    target,
    ModificationTime,
    follow_symlink=false,
  )
  @fsops.overwrite_decision(options.update, source_time, Some(destination_time))
}

///|
async fn copy_tree_with_policy(
  source : String,
  target : String,
  options : CpOptions,
  command_line : Bool,
) -> Bool {
  let target_kind = @fsops.kind_if_exists(target)
  let source_kind = @fs.kind(source, follow_symlink=false)
  let source_kind = if source_kind == SymLink &&
    (
      options.traversal == FollowAllLinks ||
      (options.traversal == FollowCommandLineLinks && command_line)
    ) {
    @fs.kind(source, follow_symlink=true)
  } else {
    source_kind
  }
  match source_kind {
    Directory => {
      match target_kind {
        Some(Directory) => ()
        None => @fs.mkdir(target)
        Some(_) =>
          raise @fsops.FsOpError("destination is not a directory: '\{target}'")
      }
      let entries = @fs.readdir(
        source,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      entries.sort_by((left, right) => left.lexical_compare(right))
      let mut copied = false
      for entry in entries {
        if copy_tree_with_policy(
            @fsops.join(source, entry),
            @fsops.join(target, entry),
            options,
            false,
          ) {
          copied = true
        }
      }
      copied || target_kind is None
    }
    Regular => {
      match replacement_decision(source, target, options) {
        SkipDestination => return false
        RejectDestination =>
          raise @fsops.FsOpError("destination exists under update=none-fail")
        ReplaceDestination => ()
      }
      if target_kind == Some(Regular) && options.interactive {
        if !confirm_overwrite(target) {
          return false
        }
      }
      let backup = match target_kind {
        Some(Regular) =>
          @fsops.backup_destination(
            target,
            options.backup,
            suffix=options.suffix,
          )
        _ => None
      }
      let backup_to_restore = backup
      errdefer (match backup_to_restore {
        Some(path) => @fsops.restore_backup(target, path) catch { _ => () }
        None => ()
      })
      ignore(
        @fsops.copy_path_with_links(
          source,
          target,
          false,
          backup is None,
          options.traversal,
        ),
      )
      true
    }
    _ => raise @fsops.FsOpError("unsupported source type: '\{source}'")
  }
}

///|
async fn copy_one(
  source : String,
  target : String,
  options : CpOptions,
) -> Bool {
  @fsops.preflight_copy_path(
    source,
    target,
    options.recursive,
    options.traversal,
  )
  copy_tree_with_policy(source, target, options, true)
}

///|
async fn main {
  let parsed = @cli.parse(normalized_args(@env.args()[1:]), [
    @cli.flag("recursive", short='R'),
    @cli.flag("recursive", short='r'),
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
    @cli.flag("interactive", short='i'),
    @cli.flag("update", short='u'),
    @cli.option("update-mode"),
    @cli.flag("backup", short='b'),
    @cli.option("backup-control"),
    @cli.option("suffix", short='S'),
    @cli.flag("dereference-command-line", short='H'),
    @cli.flag("dereference", short='L'),
    @cli.flag("no-dereference", short='P'),
    @cli.flag("no-target-directory", short='T'),
    @cli.flag("preserve", short='p'),
    @cli.flag("archive", short='a'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cp: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: cp [-R] [-H|-L|-P] [-f|-i|-n] [-u|--update=MODE] [-b|--backup[=CONTROL]] [-S SUFFIX] [-T] [-v] SOURCE... DEST\n",
    )
    return
  }
  if parsed.contains("preserve") || parsed.contains("archive") {
    @stdio.stderr.write(
      "cp: metadata and symbolic-link preservation are unavailable in the portable filesystem profile\n",
    )
    @sys.exit(1)
    return
  }
  let operands = parsed.operands
  if operands.length() < 2 {
    @stdio.stderr.write("cp: missing source or destination operand\n")
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
      @stdio.stderr.write("cp: \{message}\n")
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
      @stdio.stderr.write("cp: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let recursive = parsed.contains("recursive")
  let traversal = match
    parsed.last_occurrence([
      "dereference-command-line", "dereference", "no-dereference",
    ]) {
    Some("dereference-command-line") =>
      @fsops.LinkTraversal::FollowCommandLineLinks
    Some("dereference") => @fsops.LinkTraversal::FollowAllLinks
    Some("no-dereference") => @fsops.LinkTraversal::NeverFollowLinks
    _ => if recursive { NeverFollowLinks } else { FollowCommandLineLinks }
  }
  let options : CpOptions = {
    recursive,
    no_clobber: parsed.last_occurrence(["force", "interactive", "no-clobber"]) ==
    Some("no-clobber"),
    interactive: parsed.last_occurrence(["force", "interactive", "no-clobber"]) ==
    Some("interactive"),
    no_target_directory: parsed.contains("no-target-directory"),
    verbose: parsed.contains("verbose"),
    traversal,
    update,
    backup,
    suffix: parsed.last_value("suffix").unwrap_or("~"),
  }
  let destination = operands[operands.length() - 1]
  let sources = operands[0:operands.length() - 1]
  if options.no_target_directory && sources.length() > 1 {
    @stdio.stderr.write("cp: -T cannot be used with multiple sources\n")
    @sys.exit(1)
    return
  }
  let destination_kind = @fsops.kind_if_exists(destination) catch {
    err => {
      @stdio.stderr.write("cp: cannot inspect '\{destination}': \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if sources.length() > 1 && destination_kind != Some(Directory) {
    @stdio.stderr.write(
      "cp: destination is not a directory: '\{destination}'\n",
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
    let copied = copy_one(source, target, options) catch {
      @fsops.FsOpError(message) => {
        @stdio.stderr.write(
          "cp: cannot copy '\{source}' to '\{target}': \{message}\n",
        )
        failed = true
        false
      }
      err => {
        @stdio.stderr.write(
          "cp: cannot copy '\{source}' to '\{target}': \{err}\n",
        )
        failed = true
        false
      }
    }
    if copied && options.verbose {
      @stdio.stdout.write("'\{source}' -> '\{target}'\n")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
