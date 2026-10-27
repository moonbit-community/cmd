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
    #|  -e, --format=FORMAT     add a custom format
    #|  -f, --format-file=FILE  add formats from a file
    #|  -L, --color[=WHEN]      enable _L colors: always, auto, or never
    #|  -n, --length=N          display at most N input bytes
    #|  -s, --skip=N            skip N input bytes
    #|  -v, --no-squeezing      display duplicate blocks
    #|  -h, --help              display this help and exit
    #|  -V, --version           display version and exit
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("hexdump 0.1.3\n")
    return
  }
  let args = normalized_args(@env.args()[1:])
  let parsed = @cli.parse(args[:], [
    @cli.flag("one-byte-octal", short='b', repeatable=true),
    @cli.flag("one-byte-char", short='c', repeatable=true),
    @cli.flag("canonical", short='C', repeatable=true),
    @cli.flag("two-bytes-decimal", short='d', repeatable=true),
    @cli.flag("two-bytes-octal", short='o', repeatable=true),
    @cli.flag("two-bytes-hex", short='x', repeatable=true),
    @cli.flag("one-byte-hex", short='X', repeatable=true),
    @cli.option("format", short='e', repeatable=true),
    @cli.option("format-file", short='f', repeatable=true),
    @cli.option("color", repeatable=true),
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
  let program = program(parsed) catch {
    HexdumpError(message) => {
      @stdio.stderr.write("hexdump: \{message}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("hexdump: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  if remaining == Some(0L) || program.block_size == 0 {
    return
  }
  let state : DumpState = {
    program,
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
        state.read(@stdio.stdin)
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
  if state.offset > 0L && program.final_unit is Some(unit) {
    @stdio.stdout.write(render_final(unit, state.offset))
  }
  if failed {
    @sys.exit(1)
  }
}
