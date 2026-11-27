///|
fn expand_bytes(
  data : Bytes,
  initial_only : Bool,
  stops : TabStops,
) -> Bytes raise TabError {
  let output : Array[Byte] = []
  let mut column = 0L
  let mut seen_nonblank = false
  for byte in data {
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
      output.push(byte)
      if byte != b'\x00' {
        if column == 9223372036854775807L {
          raise TabError("input line is too long")
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
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
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
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("expand \{MODULE_VERSION}\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("expand: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let stops = parse_tabs(parsed.values("tabs")) catch {
    TabError(message) => {
      @stdio.stderr.write("expand: \{message}\n")
      @env.exit(1)
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
      TabError(message) => {
        @stdio.stderr.write("expand: \{message}\n")
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
