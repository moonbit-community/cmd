///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("mkdir \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("mkdir: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
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
