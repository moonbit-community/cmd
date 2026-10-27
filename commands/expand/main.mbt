///|
fn expand_bytes(
  data : Bytes,
  initial_only : Bool,
  stops : @tabstops.TabStops,
) -> Bytes raise @tabstops.TabError {
  let output : Array[Byte] = []
  let mut column = 0L
  let mut seen_nonblank = false
  for byte in data {
    if byte == b'\n' {
      output.push(byte)
      column = 0
      seen_nonblank = false
    } else if byte == b'\t' && (!initial_only || !seen_nonblank) {
      match @tabstops.next(column, stops) {
        Some(stop) => {
          for current = column; current < stop; current = current + 1 {
            output.push(b' ')
          }
          column = stop
        }
        None => {
          output.push(b' ')
          column += 1
        }
      }
    } else if byte == b'\b' {
      output.push(byte)
      if column > 0 {
        column -= 1
      }
      seen_nonblank = true
    } else {
      output.push(byte)
      if byte != b'\x00' {
        if column == 9223372036854775807L {
          raise @tabstops.TabError("input line is too long")
        }
        column += 1
      }
      if byte != b' ' && byte != b'\t' {
        seen_nonblank = true
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: expand [OPTION]... [FILE]...
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Convert tabs in each FILE to spaces, writing to standard output.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -i, --initial       do not convert tabs after nonblank characters
    #|  -t, --tabs=LIST     use ascending tab stops; /N repeats absolute, +N relative
  message
}

///|
async fn read_input(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("expand 0.1.4\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("initial", short='i'),
    @cli.option("tabs", short='t'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("expand: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let stops = @tabstops.parse(parsed.values("tabs")) catch {
    @tabstops.TabError(message) => {
      @stdio.stderr.write("expand: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  let sources = if parsed.operands.is_empty() {
    ["-"][:]
  } else {
    parsed.operands
  }
  let mut failed = false
  for path in sources {
    let data = read_input(path) catch {
      err => {
        @stdio.stderr.write("expand: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    let expanded = expand_bytes(data, parsed.contains("initial"), stops) catch {
      @tabstops.TabError(message) => {
        @stdio.stderr.write("expand: \{message}\n")
        @sys.exit(1)
        return
      }
    }
    @stdio.stdout.write(expanded)
  }
  if failed {
    @sys.exit(1)
  }
}
