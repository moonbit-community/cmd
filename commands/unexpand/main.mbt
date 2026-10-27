///|
fn unexpand_bytes(
  data : Bytes,
  all_blanks : Bool,
  first_only : Bool,
  stops : @tabstops.TabStops,
) -> Bytes raise @tabstops.TabError {
  let output : Array[Byte] = []
  let pending : Array[Byte] = []
  let mut column = 0L
  let mut convert = true
  let mut previous_blank = true
  let mut one_blank_before_stop = false
  fn flush_pending() {
    if pending.length() > 1 && one_blank_before_stop {
      pending[0] = b'\t'
    }
    output.append(pending)
    pending.clear()
    one_blank_before_stop = false
  }
  for byte in data {
    let mut emit_byte = true
    if convert {
      let blank = byte is (b' ' | b'\t')
      if blank {
        match @tabstops.next(column, stops) {
          None => convert = false
          Some(stop) => {
            if byte == b'\t' {
              column = stop
              if !pending.is_empty() {
                pending[0] = b'\t'
              }
            } else {
              column += 1
              if !(previous_blank && column == stop) {
                if column == stop {
                  one_blank_before_stop = true
                }
                pending.push(byte)
                previous_blank = true
                continue
              }
              output.push(b'\t')
              emit_byte = false
              if !pending.is_empty() {
                pending[0] = b'\t'
              }
            }
            if one_blank_before_stop {
              pending.truncate(1)
            } else {
              pending.clear()
            }
          }
        }
      } else if byte == b'\b' {
        if column > 0 {
          column -= 1
        }
      } else if byte != b'\x00' {
        if column == 9223372036854775807L {
          raise @tabstops.TabError("input line is too long")
        }
        column += 1
      }
      flush_pending()
      previous_blank = blank
      convert = convert && ((all_blanks && !first_only) || blank)
    }
    if emit_byte {
      output.push(byte)
    }
    if byte == b'\n' {
      column = 0
      convert = true
      previous_blank = true
    }
  }
  flush_pending()
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: unexpand [OPTION]... [FILE]...
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Convert spaces in each FILE to tabs, writing to standard output.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -a, --all          convert all blanks, not just leading blanks
    #|      --first-only   convert only leading blank sequences
    #|  -t, --tabs=LIST    use ascending stops; /N absolute, +N relative (implies --all)
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
    @stdio.stdout.write("unexpand 0.1.4\n")
    return
  }
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
  let stops = @tabstops.parse(parsed.values("tabs")) catch {
    @tabstops.TabError(message) => {
      @stdio.stderr.write("unexpand: \{message}\n")
      @sys.exit(1)
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
    let unexpanded = unexpand_bytes(
      data,
      all_blanks,
      parsed.contains("first-only"),
      stops,
    ) catch {
      @tabstops.TabError(message) => {
        @stdio.stderr.write("unexpand: \{message}\n")
        @sys.exit(1)
        return
      }
    }
    @stdio.stdout.write(unexpanded)
  }
  if failed {
    @sys.exit(1)
  }
}
