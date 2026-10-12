///|
fn help_message() -> String {
  let message =
    #|Usage: od [OPTION]... [FILE]...
    #|Dump concatenated files, or stdin when no FILE or FILE - is given.
    #|  -A, --address-radix=d|o|x|n  address base, or no addresses
    #|  -j, --skip-bytes=N          skip N input bytes
    #|  -N, --read-bytes=N          print at most N bytes
    #|  -t, --format=TYPE           a, c, d/u/o/x with size 1,2,4,8; optional z
    #|  -a -b -c -d -i -l -o -s -x  traditional named/integer formats
    #|      --endian=little|big     byte order (default little)
    #|  -w[N], --width[=N]         bytes per line (default 16, bare option 32)
    #|  -v, --output-duplicates    do not replace repeated blocks with *
    #|      --help                 display this help and exit
    #|      --version              display version and exit
  message
}

///|
fn settings(parsed : @cli.ParsedArgs) -> DumpState raise OdError {
  let base = match parsed.last_value("address-radix").unwrap_or("o") {
    "d" => 10
    "o" => 8
    "x" => 16
    "n" => 0
    _ => raise OdError("invalid address radix")
  }
  let big = match parsed.last_value("endian").unwrap_or("little") {
    "little" => false
    "big" => true
    _ => raise OdError("invalid byte order")
  }
  let formats : Array[Format] = []
  let mut type_index = 0
  let types = parsed.values("format")
  for option in parsed.order {
    let spec = match option {
      "format" => {
        let t = types[type_index]
        type_index += 1
        t
      }
      "named" => "a"
      "octal-byte" => "o1"
      "character" => "c"
      "decimal" => "u2"
      "int" => "d4"
      "long" => "d8"
      "octal" => "o2"
      "signed" => "d2"
      "hex" => "x2"
      _ => continue
    }
    formats.append(parse_formats(spec))
  }
  if formats.is_empty() {
    formats.push({ kind: 'o', size: 2, trailer: false, })
  }
  let width = @string.parse_int(parsed.last_value("width").unwrap_or("16")) catch {
    _ => raise OdError("invalid line width")
  }
  if width <= 0 || width > 1048576 {
    raise OdError("line width must be between 1 and 1048576")
  }
  for format in formats {
    if width % format.size != 0 {
      raise OdError("line width must be a multiple of every format size")
    }
  }
  let skip = parse_count(parsed.last_value("skip-bytes").unwrap_or("0"))
  let remaining = match parsed.last_value("read-bytes") {
    Some(n) => Some(parse_count(n))
    None => None
  }
  {
    formats,
    base,
    width,
    big,
    verbose: parsed.contains("output-duplicates"),
    pending: [],
    skip,
    remaining,
    offset: 0L,
    previous: None,
    squeezed: false,
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("od 0.1.0\n")
    return
  }
  let args : Array[String] = []
  let mut options = true
  for arg in @env.args()[1:] {
    if arg == "--" {
      options = false
    }
    args.push(
      if options && (arg == "-w" || arg == "--width") {
        "--width=32"
      } else {
        arg
      },
    )
  }
  let parsed = @cli.parse(args, [
    @cli.option("address-radix", short='A', repeatable=true),
    @cli.option("skip-bytes", short='j', repeatable=true),
    @cli.option("read-bytes", short='N', repeatable=true),
    @cli.option("format", short='t', repeatable=true),
    @cli.option("endian", repeatable=true),
    @cli.option("width", short='w', repeatable=true),
    @cli.flag("output-duplicates", short='v', repeatable=true),
    @cli.flag("named", short='a', repeatable=true),
    @cli.flag("octal-byte", short='b', repeatable=true),
    @cli.flag("character", short='c', repeatable=true),
    @cli.flag("decimal", short='d', repeatable=true),
    @cli.flag("int", short='i', repeatable=true),
    @cli.flag("long", short='l', repeatable=true),
    @cli.flag("octal", short='o', repeatable=true),
    @cli.flag("signed", short='s', repeatable=true),
    @cli.flag("hex", short='x', repeatable=true),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("od: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("od \{command_version}\n")
    return
  }
  let state = settings(parsed) catch {
    OdError(message) => {
      @stdio.stderr.write("od: \{message}\n")
      @sys.exit(1)
      return
    }
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
        @stdio.stderr.write("od: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if state.skip > 0L {
    @stdio.stderr.write("od: cannot skip past end of combined input\n")
    @sys.exit(1)
    return
  }
  if !state.pending.is_empty() {
    @stdio.stdout.write(state.row())
  }
  if state.base != 0 {
    @stdio.stdout.write(address(state.offset, state.base) + "\n")
  }
  if failed {
    @sys.exit(1)
  }
}
