///|
fn digit(value : Int32) -> Char {
  if value < 10 {
    ('0'.to_int() + value).to_char().unwrap()
  } else {
    ('a'.to_int() + value - 10).to_char().unwrap()
  }
}

///|
fn radix_string(value : Int64, radix : Int32) -> String {
  if value == 0 {
    return "0"
  }
  let mut number = value
  let mut result = ""
  while number > 0 {
    result = digit((number % radix.to_int64()).to_int()).to_string() + result
    number /= radix.to_int64()
  }
  result
}

///|
fn printable(byte : Byte, eight_bit : Bool) -> Bool {
  byte == 0x09 || (byte >= 0x20 && byte <= 0x7E) || (eight_bit && byte >= 0x80)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: strings [OPTION]... [FILE]...
    #|Print the sequences of printable characters in each FILE.
    #|  -a, --all             scan the whole file
    #|  -f, --print-file-name print the file name before each string
    #|  -n, --bytes=N         print sequences at least N bytes long
    #|  -o                    display offsets in octal
    #|  -t, --radix=RADIX     display offsets in d, o, or x radix
    #|  -e, --encoding=ENC    s: 7-bit bytes (default); S: 8-bit bytes
    #|                        wide encodings b/l/B/L are unsupported
    #|  -s, --output-separator=STR  separate accepted strings with STR
    #|      --help            display this help and exit
    #|      --version         display version and exit
  message
}

///|
fn parse_radix(value : String) -> Int32? {
  match value {
    "d" => Some(10)
    "o" => Some(8)
    "x" => Some(16)
    _ => None
  }
}

///|
fn record_prefix(
  path : String,
  offset : Int64,
  prefix : Bool,
  radix : Int32?,
) -> String {
  let mut line = ""
  if prefix {
    line += (if path == "-" { "{standard input}" } else { path }) + ": "
  }
  match radix {
    Some(base) => {
      let address = radix_string(offset, base)
      line += " ".repeat((7 - address.length()).max(0)) + address + " "
    }
    None => ()
  }
  line
}

///|
async fn emit_stream(
  reader : &@io.Reader,
  writer : &@io.Writer,
  path : String,
  minimum : Int32,
  prefix : Bool,
  radix : Int32?,
  eight_bit : Bool,
  separator~ : String = "\n",
) -> Unit {
  let pending : Array[Byte] = []
  let mut offset : Int64 = 0
  let mut start : Int64 = 0
  let mut emitting = false
  for ;; {
    let chunk = {
      errdefer (if emitting { writer.write(separator) })
      reader.read_some(max_len=65536)
    }
    guard chunk is Some(chunk) else { break }
    let mut index = 0
    while index < chunk.length() {
      if !printable(chunk[index], eight_bit) {
        if emitting {
          writer.write(separator)
        }
        pending.clear()
        emitting = false
        index += 1
        start = offset + index.to_int64()
        continue
      }
      let segment = index
      while index < chunk.length() && printable(chunk[index], eight_bit) {
        index += 1
      }
      if emitting {
        writer.write(chunk[segment:index])
      } else if pending.length() + index - segment >= minimum {
        writer.write(record_prefix(path, start, prefix, radix))
        if !pending.is_empty() {
          writer.write(Bytes::from_array(pending))
          pending.clear()
        }
        writer.write(chunk[segment:index])
        emitting = true
      } else {
        for byte in chunk[segment:index] {
          pending.push(byte)
        }
      }
    }
    offset += chunk.length().to_int64()
  }
  if emitting {
    writer.write(separator)
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("strings 0.1.4\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("all", short='a'),
    @cli.flag("print-file-name", short='f'),
    @cli.option("bytes", short='n'),
    @cli.flag("octal", short='o'),
    @cli.option("radix", short='t'),
    @cli.option("encoding", short='e'),
    @cli.option("output-separator", short='s'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("strings: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("strings \{command_version}\n")
    return
  }
  let minimum = @string.parse_int(parsed.last_value("bytes").unwrap_or("4")) catch {
    _ => 0
  }
  if minimum < 1 {
    @stdio.stderr.write("strings: invalid minimum string length\n")
    @sys.exit(1)
    return
  }
  if parsed.values("encoding").any(value => value != "s" && value != "S") {
    @stdio.stderr.write(
      "strings: unsupported encoding; use s (7-bit) or S (8-bit)\n",
    )
    @sys.exit(2)
    return
  }
  if parsed.values("radix").any(value => parse_radix(value) is None) {
    @stdio.stderr.write("strings: invalid radix\n")
    @sys.exit(1)
    return
  }
  let radix = if parsed.last_occurrence(["octal", "radix"]) == Some("octal") {
    Some(8)
  } else if parsed.contains("radix") {
    match parse_radix(parsed.last_value("radix").unwrap_or("")) {
      Some(value) => Some(value)
      None => {
        @stdio.stderr.write("strings: invalid radix\n")
        @sys.exit(2)
        return
      }
    }
  } else {
    None
  }
  // GNU's bare '-' selects whole-file scanning, rather than adding stdin
  // between file operands. With no remaining files, read stdin once.
  let files = parsed.operands.filter(path => path != "-")
  let sources = if files.is_empty() { ["-"] } else { files }
  let prefix = parsed.contains("print-file-name")
  let separator = parsed.last_value("output-separator").unwrap_or("\n")
  let writer = @io.BufferedWriter::new(@stdio.stdout, size=65536)
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        emit_stream(
          @stdio.stdin,
          writer,
          path,
          minimum,
          prefix,
          radix,
          parsed.last_value("encoding") == Some("S"),
          separator~,
        )
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        emit_stream(
          file,
          writer,
          path,
          minimum,
          prefix,
          radix,
          parsed.last_value("encoding") == Some("S"),
          separator~,
        )
      }
    } catch {
      err => {
        @stdio.stderr.write("strings: \{path}: \{err}\n")
        failed = true
      }
    }
  }
  writer.flush()
  if failed {
    @sys.exit(1)
  }
}
