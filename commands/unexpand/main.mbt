///|
priv suberror UnexpandError {
  UnexpandError(String)
}

///|
fn parse_stops(text : String) -> Array[Int] raise UnexpandError {
  if text == "" {
    raise UnexpandError("invalid tab size")
  }
  let stops : Array[Int] = []
  for part in text.split(",") {
    if part.trim() == "" {
      raise UnexpandError("invalid tab size")
    }
    let value = @string.parse_int(part.trim().to_owned()) catch {
      _ => raise UnexpandError("invalid tab size")
    }
    if value <= 0 || (stops.length() > 0 && value <= stops.last().unwrap_or(0)) {
      raise UnexpandError("tab sizes must be ascending")
    }
    stops.push(value)
  }
  if stops.is_empty() {
    raise UnexpandError("invalid tab size")
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
fn emit_spaces_as_tabs(
  output : Array[Byte],
  start : Int,
  count : Int,
  stops : Array[Int],
) -> Int {
  let end = start + count
  let mut column = start
  while column < end {
    match next_stop(column, stops) {
      Some(stop) if stop <= end => {
        output.push(b'\t')
        column = stop
      }
      _ => {
        output.push(b' ')
        column += 1
      }
    }
  }
  column
}

///|
fn unexpand_bytes(
  data : Bytes,
  all_blanks : Bool,
  first_only : Bool,
  stops : Array[Int],
) -> Bytes {
  let output : Array[Byte] = []
  let mut column = 0
  let mut line_has_nonblank = false
  let pending_spaces : Array[Byte] = []
  fn flush_pending() {
    if pending_spaces.is_empty() {
      return
    }
    let eligible = if first_only {
      !line_has_nonblank
    } else {
      all_blanks || !line_has_nonblank
    }
    if eligible {
      column = emit_spaces_as_tabs(
        output,
        column,
        pending_spaces.length(),
        stops,
      )
    } else {
      for _ in pending_spaces {
        output.push(b' ')
        column += 1
      }
    }
    pending_spaces.clear()
  }
  for byte in data {
    if byte == b' ' {
      pending_spaces.push(byte)
    } else {
      flush_pending()
      if byte == b'\n' {
        output.push(byte)
        column = 0
        line_has_nonblank = false
      } else if byte == b'\t' {
        output.push(byte)
        column = match next_stop(column, stops) {
          Some(stop) => stop
          None => column + 1
        }
        // A tab is still part of the initial blank prefix.
      } else if byte == b'\b' {
        output.push(byte)
        if column > 0 {
          column -= 1
        }
      } else {
        output.push(byte)
        column += 1
        line_has_nonblank = true
      }
    }
  }
  flush_pending()
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: unexpand [OPTION]... [FILE]...
    #|
    #|Convert spaces in each FILE to tabs, writing to standard output.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -a, --all          convert all blanks, not just leading blanks
    #|      --first-only   convert only leading blank sequences
    #|  -t, --tabs=LIST    use comma-separated tab stops (implies --all)
    #|      --help         display this help and exit
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
    @cli.flag("all", short='a'),
    @cli.flag("first-only"),
    @cli.option("tabs", short='t'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("unexpand: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let stops = parse_stops(parsed.last_value("tabs").unwrap_or("8")) catch {
    UnexpandError(message) => {
      @stdio.stderr.write("unexpand: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let all_blanks = parsed.contains("all") || parsed.contains("tabs")
  let sources = if parsed.operands.is_empty() {
    ["-"][:]
  } else {
    parsed.operands
  }
  let mut failed = false
  for path in sources {
    let data = read_input(path) catch {
      err => {
        @stdio.stderr.write("unexpand: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    @stdio.stdout.write(
      unexpand_bytes(data, all_blanks, parsed.contains("first-only"), stops),
    )
  }
  if failed {
    @sys.exit(1)
  }
}
