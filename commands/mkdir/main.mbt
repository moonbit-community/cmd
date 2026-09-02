///|
fn parse_mode(text : String) -> Int raise {
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
    if !(digit is ('0'..='7')) {
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
      "Usage: mkdir [-p] [-m MODE] [-v] DIRECTORY...\nNote: MODE currently accepts numeric octal permissions only.\n",
    )
    return
  }
  let permission = match parsed.last_value("mode") {
    Some(value) =>
      parse_mode(value) catch {
        _ => {
          @stdio.stderr.write("mkdir: invalid mode: '\{value}'\n")
          @sys.exit(1)
          return
        }
      }
    None => 0o755
  }
  let directories = parsed.operands
  let parents = parsed.contains("parents")
  let verbose = parsed.contains("verbose")
  if directories.is_empty() {
    @stdio.stderr.write("mkdir: missing operand\n")
    @sys.exit(1)
    return
  }
  let mut failed = false
  for directory in directories {
    let created = try {
      match @fsops.kind_if_exists(directory) {
        Some(Directory) if parents => false
        Some(_) => fail("path already exists")
        None => {
          @fs.mkdir(directory, permission~, recursive=parents)
          true
        }
      }
    } catch {
      err => {
        @stdio.stderr.write("mkdir: cannot create '\{directory}': \{err}\n")
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
