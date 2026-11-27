///|
fn expand_bytes(
  data : Bytes,
  initial_only : Bool,
  stops : TabStops,
  profile~ : @textwidth.Profile = CBytes,
) -> Bytes raise TabError {
  let output : Array[Byte] = []
  let mut column = 0L
  let mut seen_nonblank = false
  for i = 0; i < data.length(); {
    let (ch, len) = profile.next(data[:], i)
    let raw = data[i:i + len]
    let byte = raw[0]
    if byte == b'\n' {
      output.push(byte)
      column = 0
      seen_nonblank = false
    } else if byte == b'\t' && (!initial_only || !seen_nonblank) {
      match next_tab(column, stops) {
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
      for b in raw {
        output.push(b)
      }
      if byte != b'\x00' {
        let width = if profile == CBytes {
          1L
        } else {
          @textwidth.cells(ch, fallback=1).to_int64()
        }
        if 9223372036854775807L - column < width {
          raise TabError("input line is too long")
        }
        column += width
      }
      if !@textwidth.is_blank(ch) {
        seen_nonblank = true
      }
    }
    continue i + len
  }
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
async fn read_input(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all()
  } else {
    @fs.read_binary(path)
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("expand \{MODULE_VERSION}\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("expand: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(help_message() + "\n")
    return
  }
  let stops = parse_tabs(parsed.values("tabs")) catch {
    TabError(message) => {
      @stdio.stderr.text.write("expand: \{message}\n")
      @env.exit(1)
      return
    }
  }
  let sources = if parsed.operands.is_empty() {
    ["-"][:]
  } else {
    parsed.operands
  }
  let profile = @textwidth.current()
  let mut failed = false
  for path in sources {
    let data = read_input(path) catch {
      err => {
        @stdio.stderr.text.write("expand: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    let expanded = expand_bytes(
      data,
      parsed.contains("initial"),
      stops,
      profile~,
    ) catch {
      TabError(message) => {
        @stdio.stderr.text.write("expand: \{message}\n")
        @env.exit(1)
        return
      }
    }
    @stdio.stdout.write(expanded)
  }
  if failed {
    @env.exit(1)
  }
}
