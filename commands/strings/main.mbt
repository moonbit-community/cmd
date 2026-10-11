///|
fn digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).to_char().unwrap()
  } else {
    ('a'.to_int() + value - 10).to_char().unwrap()
  }
}

///|
fn radix_string(value : Int, radix : Int) -> String {
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
fn printable(byte : Byte) -> Bool {
  byte >= 0x20 && byte <= 0x7E
}

///|
fn records(data : Bytes, minimum : Int) -> Array[(Int, String)] {
  let result : Array[(Int, String)] = []
  let mut start = 0
  let mut index = 0
  while index <= data.length() {
    if index == data.length() || !printable(data[index]) {
      if index - start >= minimum {
        let text = @utf8.decode(data[start:index].to_owned()) catch { _ => "" }
        if text != "" {
          result.push((start, text))
        }
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
    #|  -t, --radix=RADIX     display offsets in b, o, or x radix
    #|      --help            display this help and exit
    #|      --version         display version and exit
  message
}

///|
fn parse_radix(value : String) -> Int? {
  match value {
    "b" => Some(2)
    "o" => Some(8)
    "x" => Some(16)
    _ => None
  }
}

///|
async fn emit(
  path : String,
  data : Bytes,
  minimum : Int,
  prefix : Bool,
  radix : Int?,
) -> Unit {
  for (offset, text) in records(data, minimum) {
    let mut line = ""
    if prefix {
      line += path + ": "
    }
    match radix {
      Some(base) => line += "\{radix_string(offset, base)} "
      None => ()
    }
    @stdio.stdout.write(line + text + "\n")
  }
}

///|
async fn main {
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
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("strings (cli) \{command_version}\n")
    return
  }
  let minimum = @string.parse_int(parsed.last_value("bytes").unwrap_or("4")) catch {
    _ => 0
  }
  if minimum < 1 {
    @stdio.stderr.write("strings: invalid minimum string length\n")
    @sys.exit(2)
    return
  }
  if parsed.contains("encoding") && parsed.last_value("encoding") != Some("b") {
    @stdio.stderr.write(
      "strings: unsupported encoding; only C-locale bytes are supported\n",
    )
    @sys.exit(2)
    return
  }
  let radix = if parsed.contains("octal") {
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
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let prefix = parsed.contains("print-file-name") || sources.length() > 1
  let mut failed = false
  for path in sources {
    let data = read_source(path) catch {
      err => {
        @stdio.stderr.write("strings: \{path}: \{err}\n")
        failed = true
        continue
      }
    }
    emit(path, data, minimum, prefix, radix)
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
