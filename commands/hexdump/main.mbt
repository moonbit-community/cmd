///|
fn help_message() -> String {
  let message =
    #|Usage: hexdump [OPTION]... [FILE]...
    #|Display concatenated files as numbers and characters; no FILE reads stdin.
    #|  -b, --one-byte-octal     one-byte octal
    #|  -c, --one-byte-char      escaped characters
    #|  -C, --canonical         hexadecimal bytes with ASCII
    #|  -d, --two-bytes-decimal  two-byte unsigned decimal
    #|  -o, --two-bytes-octal    two-byte octal
    #|  -x, --two-bytes-hex      two-byte hexadecimal
    #|  -X, --one-byte-hex       one-byte hexadecimal
    #|  -n, --length=N          display at most N input bytes
    #|  -s, --skip=N            skip N input bytes in named files
    #|  -v, --no-squeezing      display duplicate blocks
    #|  -h, --help              display this help and exit
    #|  -V, --version           display version and exit
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("hexdump 0.1.0\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("one-byte-octal", short='b', repeatable=true),
    @cli.flag("one-byte-char", short='c', repeatable=true),
    @cli.flag("canonical", short='C', repeatable=true),
    @cli.flag("two-bytes-decimal", short='d', repeatable=true),
    @cli.flag("two-bytes-octal", short='o', repeatable=true),
    @cli.flag("two-bytes-hex", short='x', repeatable=true),
    @cli.flag("one-byte-hex", short='X', repeatable=true),
    @cli.option("length", short='n', repeatable=true),
    @cli.option("skip", short='s', repeatable=true),
    @cli.flag("no-squeezing", short='v', repeatable=true),
    @cli.flag("help", short='h'),
    @cli.flag("version", short='V'),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("hexdump: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("hexdump \{command_version}\n")
    return
  }
  let (skip, remaining) = try {
    let skip = parse_count(parsed.last_value("skip").unwrap_or("0"))
    let remaining = match parsed.last_value("length") {
      Some(n) => Some(parse_count(n))
      None => None
    }
    (skip, remaining)
  } catch {
    HexdumpError(message) => {
      @stdio.stderr.write("hexdump: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  let modes : Array[String] = []
  if remaining == Some(0L) {
    return
  }
  for name in parsed.order {
    if name == "one-byte-octal" ||
      name == "one-byte-char" ||
      name == "canonical" ||
      name == "two-bytes-decimal" ||
      name == "two-bytes-octal" ||
      name == "two-bytes-hex" ||
      name == "one-byte-hex" {
      modes.push(name)
    }
  }
  if modes.is_empty() {
    modes.push("default")
  }
  let state : DumpState = {
    modes,
    verbose: parsed.contains("no-squeezing"),
    pending: [],
    skip,
    remaining,
    offset: 0L,
    previous: None,
    squeezed: false,
  }
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut failed = false
  for path in sources {
    if state.skip == 0L && state.remaining == Some(0L) {
      break
    }
    try {
      if path == "-" {
        if state.skip > 0L {
          @stdio.stderr.write(
            "hexdump: skipping stdin requires a public seekable-stream API\n",
          )
          failed = true
          break
        } else {
          state.read(@stdio.stdin)
        }
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        state.read(file)
      }
    } catch {
      err => {
        @stdio.stderr.write("hexdump: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if !state.pending.is_empty() {
    @stdio.stdout.write(state.row())
  }
  if state.offset > 0L {
    @stdio.stdout.write(
      number(
        state.offset,
        16,
        if modes.last() == Some("canonical") {
          8
        } else {
          7
        },
      ) +
      "\n",
    )
  }
  if failed {
    @sys.exit(1)
  }
}
