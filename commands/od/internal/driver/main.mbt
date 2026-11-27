///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
fn settings(parsed : @cli.ParsedArgs) -> DumpState raise OdError {
  let base = match
    parsed.last_value("address-radix").unwrap_or(DEFAULT_ADDRESS_RADIX) {
    "d" => 10
    "o" => 8
    "x" => 16
    "n" => 0
    _ => raise OdError("invalid address radix")
  }
  let big = match parsed.last_value("endian").unwrap_or(DEFAULT_ENDIAN) {
    "little" => false
    "big" => true
    _ => raise OdError("invalid byte order")
  }
  let formats : Array[@format.Format] = []
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
    formats.append(
      @format.parse_formats(spec) catch {
        @format.FormatError(message) => raise OdError(message)
      },
    )
  }
  if parsed.contains("strings") && !formats.is_empty() {
    raise OdError("no type may be specified when dumping strings")
  }
  if formats.is_empty() {
    formats.append(
      @format.parse_formats("o2") catch {
        @format.FormatError(message) => raise OdError(message)
      },
    )
  }
  let requested_width = @string.parse_int(
    parsed.last_value("width").unwrap_or(DEFAULT_WIDTH),
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
  let skip = parse_count(
    parsed.last_value("skip-bytes").unwrap_or(DEFAULT_SKIP_BYTES),
  )
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
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("od \{MODULE_VERSION}\n")
    return
  }
  let args : Array[String] = []
  let mut options = true
  for index, arg in metadata_args {
    if arg == "--" {
      options = false
    }
    if options && arg == "-S" && index == metadata_args.length() - 1 {
      @stdio.stderr.text.write(
        "od: option requires an argument -- 'S'\nTry 'od --help' for more information.\n",
      )
      @env.exit(1)
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
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("od: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("od \{MODULE_VERSION}\n")
    return
  }
  let state = settings(parsed) catch {
    OdError(message) => {
      @stdio.stderr.text.write("od: \{message}\n")
      @env.exit(1)
      return
    }
  }
  if parsed.last_value("width") is Some(value) {
    let requested = @string.parse_int(value) catch { _ => 0 }
    if requested != 0 && requested != state.width {
      @stdio.stderr.text.write(
        "od: warning: invalid width \{requested}; using \{state.width} instead\n",
      )
    }
  }
  let (files, old_skip, label) = traditional_operands(parsed) catch {
    OdError(message) => {
      @stdio.stderr.text.write("od: \{message}\n")
      @env.exit(1)
      return
    }
  }
  if old_skip is Some(skip) {
    state.skip = skip
  }
  state.label = label.map(start => start - state.skip)
  let sources = if files.is_empty() { ["-"] } else { files }
  if parsed.contains("strings") {
    let minimum = parse_count(
      parsed.last_value("strings").unwrap_or(DEFAULT_STRINGS),
    ) catch {
      OdError(message) => {
        @stdio.stderr.text.write("od: \{message}\n")
        @env.exit(1)
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
          @stdio.stderr.text.write("od: \{source}: \{error}\n")
          failed = true
        }
      }
    }
    if !opened {
      if failed {
        @env.exit(1)
      }
      return
    }
    if strings.skip > 0L {
      @stdio.stderr.text.write("od: cannot skip past end of combined input\n")
      failed = true
    }
    if failed {
      @env.exit(1)
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
        @stdio.stderr.text.write("od: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  if !opened {
    if failed {
      @env.exit(1)
    }
    return
  }
  if state.skip > 0L {
    @stdio.stderr.text.write("od: cannot skip past end of combined input\n")
    @env.exit(1)
    return
  }
  if !state.pending.is_empty() {
    @stdio.stdout.text.write(state.row())
  }
  if state.base != 0 || state.label is Some(_) {
    @stdio.stdout.text.write(
      @format.labeled_address(state.offset, state.base, state.label) + "\n",
    )
  }
  if failed {
    @env.exit(1)
  }
}
