///|
fn digit(value : Int32) -> Char {
  if value < 10 {
    ('0'.to_int() + value).to_char().unwrap()
  } else {
    ('a'.to_int() + value - 10).to_char().unwrap()
  }
}

///|
fn radix_string(value : Int32, radix : Int32) -> String {
  if value == 0 {
    return "0"
  }
  let mut number = value
  let mut result = ""
  while number > 0 {
    result = digit(number % radix).to_string() + result
    number /= radix
  }
  result
}

///|
fn printable(byte : Byte, eight_bit : Bool) -> Bool {
  byte == 0x09 || (byte >= 0x20 && byte <= 0x7E) || (eight_bit && byte >= 0x80)
}

///|
fn records(
  data : Bytes,
  minimum : Int32,
  eight_bit~ : Bool = false,
) -> Array[(Int32, Bytes)] {
  let result : Array[(Int32, Bytes)] = []
  let mut start = 0
  let mut index = 0
  while index <= data.length() {
    if index == data.length() || !printable(data[index], eight_bit) {
      if index - start >= minimum {
        result.push((start, data[start:index].to_owned()))
      }
      index += 1
      start = index
    } else {
      index += 1
    }
  }
  result
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
async fn emit(
  path : String,
  data : Bytes,
  minimum : Int32,
  prefix : Bool,
  radix : Int32?,
  eight_bit : Bool,
) -> Unit {
  for (offset, text) in records(data, minimum, eight_bit~) {
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
    @stdio.stdout.write(line)
    @stdio.stdout.write(text)
    @stdio.stdout.write("\n")
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("strings 0.1.3\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("all", short='a'),
    @cli.flag("print-file-name", short='f'),
    @cli.option("bytes", short='n'),
    @cli.flag("octal", short='o'),
    @cli.option("radix", short='t'),
    @cli.option("encoding", short='e'),
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
  let mut failed = false
  for path in sources {
    let data = read_source(path) catch {
      err => {
        @stdio.stderr.write("strings: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    emit(
      path,
      data,
      minimum,
      prefix,
      radix,
      parsed.last_value("encoding") == Some("S"),
    )
  }
  if failed {
    @sys.exit(1)
  }
}

///|
async fn read_source(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}
