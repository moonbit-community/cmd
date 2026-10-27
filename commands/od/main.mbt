///|
fn help_message() -> String {
  let message =
    #|Usage: od [OPTION]... [FILE]...
    #|Dump concatenated files, or stdin when no FILE or FILE - is given.
    #|  -A, --address-radix=d|o|x|n  address base, or no addresses
    #|  -j, --skip-bytes=N          skip N input bytes
    #|  -N, --read-bytes=N          print at most N bytes
    #|  -t, --format=TYPE           a, c, integers 1/2/4/8; floats 2/4/8/16; optional z
    #|  -a -b -c -d -i -l -o -s -x  traditional named/integer formats
    #|  -f -e -F                    traditional float or double formats
    #|      --endian=little|big     byte order (default little)
    #|  -w[N], --width[=N]         bytes per line (default 16, bare option 32)
    #|  -v, --output-duplicates    do not replace repeated blocks with *
    #|  -S N, --strings[=N]       print NUL-terminated printable strings (default 3)
    #|      --traditional        accept old offset and label operands
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
      "float" => "fF"
      "double" | "double-F" => "fD"
      _ => continue
    }
    formats.append(parse_formats(spec))
  }
  if parsed.contains("strings") && !formats.is_empty() {
    raise OdError("no type may be specified when dumping strings")
  }
  if formats.is_empty() {
    formats.push({ kind: 'o', size: 2, trailer: false, floating: None, })
  }
  let requested_width = @string.parse_int(
    parsed.last_value("width").unwrap_or("16"),
  ) catch {
    _ => raise OdError("invalid line width")
  }
  if requested_width < 0 || requested_width > 1048576 {
    raise OdError("line width must be between 1 and 1048576")
  }
  let mut type_width = 1
  for format in formats {
    type_width = type_width.max(format.size)
  }
  let width = if requested_width == 0 {
    Int32::max(16, type_width)
  } else if requested_width % type_width != 0 {
    type_width
  } else {
    requested_width
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
    label: None,
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("od 0.1.3\n")
    return
  }
  let args : Array[String] = []
  let mut options = true
  for index, arg in metadata_args {
    if arg == "--" {
      options = false
    }
    if options && arg == "-S" && index == metadata_args.length() - 1 {
      @stdio.stderr.write(
        "od: option requires an argument -- 'S'\nTry 'od --help' for more information.\n",
      )
      @sys.exit(1)
      return
    }
    args.push(
      if options && arg == "--strings" {
        "--strings=3"
      } else if options && (arg == "-w" || arg == "--width") {
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
    @cli.flag("float", short='f', repeatable=true),
    @cli.flag("double", short='e', repeatable=true),
    @cli.flag("double-F", short='F', repeatable=true),
    @cli.option("strings", short='S', repeatable=true),
    @cli.flag("traditional"),
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
  if parsed.last_value("width") is Some(value) {
    let requested = @string.parse_int(value) catch { _ => 0 }
    if requested != 0 && requested != state.width {
      @stdio.stderr.write(
        "od: warning: invalid width \{requested}; using \{state.width} instead\n",
      )
    }
  }
  let (files, old_skip, label) = traditional_operands(parsed) catch {
    OdError(message) => {
      @stdio.stderr.write("od: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  if old_skip is Some(skip) {
    state.skip = skip
  }
  state.label = label.map(start => start - state.skip)
  let sources = if files.is_empty() { ["-"] } else { files }
  if parsed.contains("strings") {
    let minimum = parse_count(parsed.last_value("strings").unwrap_or("3")) catch {
      OdError(message) => {
        @stdio.stderr.write("od: \{message}\n")
        @sys.exit(1)
        return
      }
    }
    let strings : StringDump = {
      minimum,
      base: state.base,
      label: state.label,
      pending: [],
      skip: state.skip,
      remaining: state.remaining,
      offset: 0L,
      start: 0L,
    }
    let mut failed = false
    let mut opened = false
    for source in sources {
      if opened && strings.done() {
        break
      }
      try {
        if source == "-" {
          opened = true
          strings.read(@stdio.stdin)
        } else {
          let file = @fs.open(source, mode=ReadOnly)
          defer file.close()
          opened = true
          strings.read(file)
        }
      } catch {
        error => {
          @stdio.stderr.write("od: \{source}: \{error}\n")
          failed = true
        }
      }
    }
    if !opened {
      if failed {
        @sys.exit(1)
      }
      return
    }
    if strings.skip > 0L {
      @stdio.stderr.write("od: cannot skip past end of combined input\n")
      failed = true
    }
    if failed {
      @sys.exit(1)
    }
    return
  }
  let mut failed = false
  let mut opened = false
  for path in sources {
    if opened && state.skip == 0L && state.remaining == Some(0L) {
      break
    }
    try {
      if path == "-" {
        opened = true
        state.read(@stdio.stdin)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        opened = true
        state.read(file)
      }
    } catch {
      err => {
        @stdio.stderr.write("od: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if !opened {
    if failed {
      @sys.exit(1)
    }
    return
  }
  if state.skip > 0L {
    @stdio.stderr.write("od: cannot skip past end of combined input\n")
    @sys.exit(1)
    return
  }
  if !state.pending.is_empty() {
    @stdio.stdout.write(state.row())
  }
  if state.base != 0 || state.label is Some(_) {
    @stdio.stdout.write(
      labeled_address(state.offset, state.base, state.label) + "\n",
    )
  }
  if failed {
    @sys.exit(1)
  }
}
