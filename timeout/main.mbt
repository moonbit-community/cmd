///|
fn parse_duration(value : String) -> Int raise {
  let mut multiplier = 1000
  let mut number = value
  if value.has_suffix("ms") {
    multiplier = 1
    number = value[:value.length() - 2].to_owned()
  } else if value.has_suffix("s") {
    number = value[:value.length() - 1].to_owned()
  } else if value.has_suffix("m") {
    multiplier = 60 * 1000
    number = value[:value.length() - 1].to_owned()
  } else if value.has_suffix("h") {
    multiplier = 60 * 60 * 1000
    number = value[:value.length() - 1].to_owned()
  } else if value.has_suffix("d") {
    multiplier = 24 * 60 * 60 * 1000
    number = value[:value.length() - 1].to_owned()
  }
  let parsed = @string.parse_double(number)
  if parsed < 0.0 ||
    parsed != parsed ||
    parsed > 2147483647.0 / multiplier.to_double() {
    fail("duration out of range")
  }
  (parsed * multiplier.to_double()).ceil().to_int()
}

///|
async fn main {
  let args = @env.args()[1:]
  let mut duration : Int? = None
  let command : Array[String] = []
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if duration is Some(_) {
      command.push(arg)
    } else if options && arg == "--" {
      options = false
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: timeout DURATION COMMAND [ARG...]\n")
      return
    } else if options && (arg == "--preserve-status" || arg == "--foreground") {
      @stdio.stderr.write("timeout: unsupported option: \{arg}\n")
      @sys.exit(125)
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("timeout: unsupported option: \{arg}\n")
      @sys.exit(125)
      return
    } else {
      duration = Some(
        parse_duration(arg) catch {
          _ => {
            @stdio.stderr.write("timeout: invalid duration: \{arg}\n")
            @sys.exit(125)
            return
          }
        },
      )
    }
    i += 1
  }
  let milliseconds = match duration {
    Some(value) => value
    None => {
      @stdio.stderr.write("timeout: missing duration\n")
      @sys.exit(125)
      return
    }
  }
  if command.is_empty() {
    @stdio.stderr.write("timeout: missing command\n")
    @sys.exit(125)
    return
  }
  let result = @async.with_timeout_opt(milliseconds, () => {
    @process.run(command[0], command[1:], cancel_handler=@process.hard_cancel())
  }) catch {
    @os_error.OSError(_) as err => {
      @stdio.stderr.write("timeout: cannot run '\{command[0]}': \{err}\n")
      @sys.exit(if err.is_ENOENT() { 127 } else { 126 })
      return
    }
    err => {
      @stdio.stderr.write("timeout: cannot run '\{command[0]}': \{err}\n")
      @sys.exit(126)
      return
    }
  }
  match result {
    Some(code) => if code != 0 { @sys.exit(code) }
    None => {
      @stdio.stderr.write("timeout: command timed out\n")
      @sys.exit(124)
    }
  }
}
