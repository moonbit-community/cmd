///|
fn parse_mode(text : String) -> Int32 raise {
  let digits = if text.has_prefix("0o") || text.has_prefix("0O") {
    text[2:].to_owned()
  } else {
    text
  }
  if digits == "" {
    fail("empty mode")
  }
  let mut value = 0
  for digit in digits {
    if !(digit is ('0'..<='7')) {
      fail("invalid mode")
    }
    value = value * 8 + digit.to_int() - '0'.to_int()
    if value > 0o7777 {
      fail("mode out of range")
    }
  }
  value
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("mkdir 0.2.2\n")
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
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: mkdir [-p] [-m MODE] [-v] DIRECTORY...\n      --help      display this help and exit\n      --version   display version and exit\nMODE accepts octal or symbolic permissions (rwxXst, copied classes and comma clauses).\nSticky-only +t yields 1755; a=rwx,+t yields 1777.\nOmitted-who expressions requiring the process umask are unavailable.\n",
    )
    return
  }
  let mut symbolic = false
  let permission = match parsed.last_value("mode") {
    Some(value) =>
      parse_mode(value) catch {
        _ => {
          symbolic = true
          symbolic_mode(value) catch {
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
  if symbolic && !@platform.permission_mutation_supported() {
    for directory in directories {
      if parents && directory_exists(directory) {
        continue
      }
      @stdio.stderr.write(
        "mkdir: unsupported capability: symbolic directory permission setter\n",
      )
      @sys.exit(2)
      return
    }
  }
  let mut failed = false
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
  if failed {
    @sys.exit(1)
  }
}
