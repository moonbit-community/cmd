///|
priv suberror ExpandError {
  ExpandError(String)
}

///|
fn parse_stops(text : String) -> Array[Int] raise ExpandError {
  if text == "" {
    raise ExpandError("invalid tab size")
  }
  let stops : Array[Int] = []
  for part in text.split(",") {
    if part.trim() == "" {
      raise ExpandError("invalid tab size")
    }
    let value = @string.parse_int(part.trim().to_owned()) catch {
      _ => raise ExpandError("invalid tab size")
    }
    if value <= 0 || (stops.length() > 0 && value <= stops.last().unwrap_or(0)) {
      raise ExpandError("tab sizes must be ascending")
    }
    stops.push(value)
  }
  if stops.is_empty() {
    raise ExpandError("invalid tab size")
  }
  stops
}

///|
fn next_stop(column : Int, stops : Array[Int]) -> Int? {
  for stop in stops {
    if stop > column {
      return Some(stop)
    }
  }
  if stops.length() == 1 {
    let width = stops[0]
    return Some((column / width + 1) * width)
  }
  None
}

///|
fn expand_bytes(data : Bytes, initial_only : Bool, stops : Array[Int]) -> Bytes {
  let output : Array[Byte] = []
  let mut column = 0
  let mut seen_nonblank = false
  for byte in data {
    if byte == b'\n' {
      output.push(byte)
      column = 0
      seen_nonblank = false
    } else if byte == b'\t' && (!initial_only || !seen_nonblank) {
      match next_stop(column, stops) {
        Some(stop) => {
          for _ in 0..<(stop - column) {
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
      column += 1
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
    #|
    #|Convert tabs in each FILE to spaces, writing to standard output.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -i, --initial       do not convert tabs after nonblank characters
    #|  -t, --tabs=LIST     use comma-separated tab stops (positive, ascending)
    #|      --help          display this help and exit
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
  let stops = parse_stops(parsed.last_value("tabs").unwrap_or("8")) catch {
    ExpandError(message) => {
      @stdio.stderr.write("expand: \{message}\n")
      @sys.exit(2)
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
    @stdio.stdout.write(expand_bytes(data, parsed.contains("initial"), stops))
  }
  if failed {
    @sys.exit(1)
  }
}
