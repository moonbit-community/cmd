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
  let directories : Array[String] = []
  let mut parents = false
  let mut verbose = false
  let mut permission = 0o755
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-m" || arg == "--mode") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("mkdir: missing mode\n")
        @sys.exit(1)
        return
      }
      i += 1
      permission = parse_mode(args[i]) catch {
        _ => {
          @stdio.stderr.write("mkdir: invalid mode: '\{args[i]}'\n")
          @sys.exit(1)
          return
        }
      }
    } else if options && arg.has_prefix("--mode=") {
      permission = parse_mode(arg[7:].to_owned()) catch {
        _ => {
          @stdio.stderr.write("mkdir: invalid mode: '\{arg[7:]}'\n")
          @sys.exit(1)
          return
        }
      }
    } else if options && arg.has_prefix("-m") && arg.length() > 2 {
      permission = parse_mode(arg[2:].to_owned()) catch {
        _ => {
          @stdio.stderr.write("mkdir: invalid mode: '\{arg[2:]}'\n")
          @sys.exit(1)
          return
        }
      }
    } else if options && arg == "--parents" {
      parents = true
    } else if options && arg == "--verbose" {
      verbose = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: mkdir [-p] [-m MODE] [-v] DIRECTORY...\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          'p' => parents = true
          'v' => verbose = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("mkdir: invalid option: '\{arg}'\n")
        @sys.exit(1)
        return
      }
    } else {
      directories.push(arg)
    }
    i += 1
  }
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
