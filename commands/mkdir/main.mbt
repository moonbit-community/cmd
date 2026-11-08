///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("mkdir 0.2.7\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("parents", short='p'),
    @cli.option("mode", short='m'),
    @cli.flag("verbose", short='v'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("mkdir: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: mkdir [-p] [-m MODE] [-v] DIRECTORY...\n      --help      display this help and exit\n      --version   display version and exit\nMODE accepts octal or symbolic permissions (rwxXst, copied classes and comma clauses).\nSticky-only +t yields 1755 on Linux and 1777 on macOS; a=rwx,+t yields 1777.\nOmitted-who expressions requiring the process umask are unavailable.\nNew POSIX parents failing public write/search checks cause status 2; created parents remain.\nPassing access checks does not establish GNU parent-mode parity under restrictive umasks or ACLs.\nWindows explicit modes reject before creation; -p existing directories remain no-ops.\nOrdinary option/operand errors exit 1; capability refusals exit 2.\n",
    )
    return
  }
  let mut symbolic = false
  let creation_retains_sticky = match @async.platform {
    MacOS => false
    Linux | Windows => true
  }
  let permission = match parsed.last_value("mode") {
    Some(value) =>
      octal_mode(value) catch {
        _ => {
          symbolic = true
          symbolic_mode(value, creation_retains_sticky~) catch {
            InvalidMode => {
              @stdio.stderr.write("mkdir: invalid mode '\{value}'\n")
              @sys.exit(1)
              return
            }
            NeedsUmask => {
              @stdio.stderr.write(
                "mkdir: unsupported capability: symbolic mode requires process umask\n",
              )
              @sys.exit(2)
              return
            }
          }
        }
      }
    None => 0o777
  }
  let directories = parsed.operands
  let parents = parsed.contains("parents")
  let verbose = parsed.contains("verbose")
  if directories.is_empty() {
    @stdio.stderr.write("mkdir: missing operand\n")
    @sys.exit(1)
    return
  }
  if parsed.contains("mode") && !@platform.permission_mutation_supported() {
    for directory in directories {
      if parents && directory_exists(directory) {
        continue
      }
      let setter = if symbolic {
        "symbolic directory permission setter"
      } else {
        "directory permission setter"
      }
      @stdio.stderr.write("mkdir: unsupported capability: \{setter}\n")
      @sys.exit(2)
      return
    }
  }
  let mut failed = false
  let mut unavailable = false
  for directory in directories {
    let created = try {
      if parents && directory_exists(directory) {
        false
      } else {
        if parents {
          create_parents(@fsops.dirname(directory), verbose)
        }
        @fs.mkdir(directory, permission~)
        if parsed.contains("mode") {
          @fs.chmod(directory, permission)
        }
        true
      }
    } catch {
      ParentPermissionUnavailable(path) => {
        @stdio.stderr.write(
          "mkdir: unsupported capability: parent permission adjustment for '\{path}'; created parents are retained\n",
        )
        unavailable = true
        false
      }
      err => {
        @stdio.stderr.write(
          "mkdir: cannot create directory '\{directory}': \{mkdir_error(err)}\n",
        )
        failed = true
        false
      }
    }
    if created && verbose {
      @stdio.stdout.write("mkdir: created directory '\{directory}'\n")
    }
  }
  if unavailable {
    @sys.exit(2)
  } else if failed {
    @sys.exit(1)
  }
}
