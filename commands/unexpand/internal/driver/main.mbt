///|
fn unexpand_bytes(
  data : Bytes,
  all_blanks : Bool,
  first_only : Bool,
  stops : TabStops,
  profile~ : @textwidth.Profile = CBytes,
) -> Bytes raise TabError {
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
  for i = 0; i < data.length(); {
    let (ch, len) = profile.next(data[:], i)
    let raw = data[i:i + len]
    let byte = raw[0]
    let mut emit_byte = true
    if convert {
      let blank = @textwidth.is_blank(ch)
      if blank {
        match next_tab(column, stops) {
          None => convert = false
          Some(stop) => {
            if byte == b'\t' {
              column = stop
              if !pending.is_empty() {
                pending[0] = b'\t'
              }
            } else {
              column += @textwidth.cells(ch, fallback=1).to_int64()
              if !(previous_blank && column == stop) {
                if column == stop {
                  one_blank_before_stop = true
                }
                for b in raw {
                  pending.push(b)
                }
                previous_blank = true
                continue i + len
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
      flush_pending()
      previous_blank = blank
      convert = convert && ((all_blanks && !first_only) || blank)
    }
    if emit_byte {
      for b in raw {
        output.push(b)
      }
    }
    if byte == b'\n' {
      column = 0
      convert = true
      previous_blank = true
    }
    continue i + len
  }
  flush_pending()
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
    @stdio.stdout.text.write("unexpand \{MODULE_VERSION}\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("unexpand: \{message}: '\{option}'\n")
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
      @stdio.stderr.text.write("unexpand: \{message}\n")
      @env.exit(1)
      return
    }
  }
  let all_blanks = parsed.contains("all") || parsed.contains("tabs")
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
        @stdio.stderr.text.write("unexpand: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    let unexpanded = unexpand_bytes(
      data,
      all_blanks,
      parsed.contains("first-only"),
      stops,
      profile~,
    ) catch {
      TabError(message) => {
        @stdio.stderr.text.write("unexpand: \{message}\n")
        @env.exit(1)
        return
      }
    }
    @stdio.stdout.write(unexpanded)
  }
  if failed {
    @env.exit(1)
  }
}
