///|
priv struct CpOptions {
  remove_destination : Bool
  recursive : Bool
  no_clobber : Bool
  no_target_directory : Bool
  verbose : Bool
  traversal : LinkTraversal
  update : @fsops.UpdateMode
  preserve_permissions : Bool
}

///|
fn normalized_args(
  args : ArrayView[String],
) -> Array[String] raise @cli.CliError {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      result.push(arg)
      value_next = false
      continue
    }
    if options &&
      ["--update-mode", "--backup-control"].any(name => {
        arg == name || arg.has_prefix(name + "=")
      }) {
      raise @cli.CliError(
        kind=UnknownOption,
        option=arg,
        message="unknown option",
      )
    }
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
    if options {
      value_next = ["--suffix", "--no-preserve"].contains(arg)
      if arg.has_prefix("-") && !arg.has_prefix("--") {
        for offset in 1..<arg.length() {
          if arg[offset] == 'S' {
            value_next = offset + 1 == arg.length()
            break
          }
        }
      }
    }
  }
  result
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
async fn copy_one(
  source : String,
  target : String,
  options : CpOptions,
) -> Bool {
  // A no-op selected by the command does not require copy capabilities.
  let kind = @fs.kind(source) catch {
    @os_error.OSError(_) as err if options.remove_destination && err.is_ENOENT() =>
      raise RemoveDestinationError(
        "cannot stat '\{source}': No such file or directory",
      )
    error => raise error
  }
  if kind == Regular {
    match replacement_decision(source, target, options) {
      SkipDestination => return false
      RejectDestination =>
        raise @fsops.FsOpError("destination exists under update=none-fail")
      ReplaceDestination => ()
    }
  }
  if options.remove_destination {
    guard !options.preserve_permissions else {
      raise @fsops.FsOpError("--remove-destination requires --no-preserve=mode")
    }
    return copy_removing_destination(
      source,
      target,
      options.traversal,
      verbose=options.verbose,
    )
  }
  copy_path_with_links(
    source,
    target,
    options.recursive,
    false,
    options.traversal,
    preserve_permissions=options.preserve_permissions,
  )
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("cp \{MODULE_VERSION}\n")
    return
  }
  let parsed = @cli.parse(normalized_args(@env.args()[1:]), option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cp: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  if parsed.contains("preserve") || parsed.contains("archive") {
    @stdio.stderr.write(
      "cp: metadata and symbolic-link preservation are unavailable in the portable filesystem profile\n",
    )
    @env.exit(1)
    return
  }
  if parsed.last_value("no-preserve") is Some(value) && value != "mode" {
    @stdio.stderr.write("cp: only --no-preserve=mode is currently supported\n")
    @env.exit(1)
    return
  }
  let operands = parsed.operands
  if operands.length() < 2 {
    @stdio.stderr.write("cp: missing source or destination operand\n")
    @env.exit(1)
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
      @env.exit(1)
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
      @env.exit(1)
      return
    }
  }
  let remove_destination = parsed.contains("remove-destination")
  let recursive = parsed.contains("recursive")
  if remove_destination &&
    (
      operands.length() != 2 ||
      recursive ||
      parsed.contains("interactive") ||
      backup != NoBackup
    ) {
    @stdio.stderr.write(
      "cp: --remove-destination supports one nonrecursive source without interaction or backups\n",
    )
    @env.exit(1)
    return
  }
  let traversal = match
    parsed.last_occurrence([
      "dereference-command-line", "dereference", "no-dereference",
    ]) {
    Some("dereference-command-line") => LinkTraversal::FollowCommandLineLinks
    Some("dereference") => LinkTraversal::FollowAllLinks
    Some("no-dereference") => LinkTraversal::NeverFollowLinks
    _ => if recursive { NeverFollowLinks } else { FollowCommandLineLinks }
  }
  let options : CpOptions = {
    remove_destination,
    recursive,
    no_clobber: parsed.last_occurrence(["force", "interactive", "no-clobber"]) ==
    Some("no-clobber"),
    no_target_directory: parsed.contains("no-target-directory"),
    verbose: parsed.contains("verbose"),
    traversal,
    update,
    preserve_permissions: !parsed.contains("no-preserve"),
  }
  let destination = operands[operands.length() - 1]
  let sources = operands[0:operands.length() - 1]
  if options.no_target_directory && sources.length() > 1 {
    @stdio.stderr.write("cp: -T cannot be used with multiple sources\n")
    @env.exit(1)
    return
  }
  let destination_kind = try {
    let kind = @fsops.kind_if_exists(destination)
    if remove_destination &&
      !options.no_target_directory &&
      kind is Some(SymLink) {
      Some(@fs.kind(destination)) catch {
        @os_error.OSError(_) as err if err.is_ENOENT() => kind
        error => raise error
      }
    } else {
      kind
    }
  } catch {
    err => {
      @stdio.stderr.write("cp: cannot inspect '\{destination}': \{err}\n")
      @env.exit(1)
      return
    }
  }
  if sources.length() > 1 && destination_kind != Some(Directory) {
    @stdio.stderr.write(
      "cp: destination is not a directory: '\{destination}'\n",
    )
    @env.exit(1)
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
      RemoveDestinationError(message) => {
        @stdio.stderr.write("cp: \{message}\n")
        failed = true
        false
      }
      err => {
        let message = match err {
          @fsops.FsOpError(message) => message
          _ => err.to_string()
        }
        @stdio.stderr.write(
          "cp: cannot copy '\{source}' to '\{target}': \{message}\n",
        )
        failed = true
        false
      }
    }
    if copied && options.verbose && !options.remove_destination {
      @stdio.stdout.write("'\{source}' -> '\{target}'\n")
    }
  }
  if failed {
    @env.exit(1)
  }
}
