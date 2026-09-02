///|
priv struct CpOptions {
  recursive : Bool
  mut no_clobber : Bool
  no_target_directory : Bool
  verbose : Bool
}

///|
async fn main {
  let raw_args = @env.args()[1:]
  let args = raw_args.map(arg => {
    if arg.has_prefix("--preserve=") {
      "--preserve"
    } else {
      arg
    }
  })
  let parsed = @cli.parse(args, [
    @cli.flag("recursive", short='R'),
    @cli.flag("recursive", short='r'),
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
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
      "Usage: cp [-R] [-a|-p] [-f|-n] [-T] [-v] SOURCE... DEST\nNote: symbolic-link sources and -a/-p preservation are unavailable without portable readlink/metadata APIs.\n",
    )
    return
  }
  let operands = parsed.operands
  let options : CpOptions = {
    recursive: parsed.contains("recursive"),
    no_clobber: parsed.contains("no-clobber"),
    no_target_directory: parsed.contains("no-target-directory"),
    verbose: parsed.contains("verbose"),
  }
  if parsed.last_occurrence(["force", "no-clobber"]) == Some("force") {
    options.no_clobber = false
  }
  if operands.length() < 2 {
    @stdio.stderr.write("cp: missing source or destination operand\n")
    @sys.exit(1)
    return
  }
  if parsed.contains("preserve") || parsed.contains("archive") {
    @stdio.stderr.write(
      "cp: metadata/link preservation is unavailable in the portable filesystem API\n",
    )
    @sys.exit(1)
    return
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
    let copied = @fsops.copy_path(
      source,
      target,
      options.recursive,
      !options.no_clobber,
    ) catch {
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
