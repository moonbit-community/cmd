///|
fn starts_with_at(data : Bytes, index : Int, separator : Bytes) -> Bool {
  if index + separator.length() > data.length() {
    return false
  }
  for offset in 0..<separator.length() {
    if data[index + offset] != separator[offset] {
      return false
    }
  }
  true
}

///|
fn split_records(data : Bytes, separator : Bytes) -> (Array[Bytes], Bool) {
  let records : Array[Bytes] = []
  let mut start = 0
  let mut index = 0
  while index + separator.length() <= data.length() {
    if starts_with_at(data, index, separator) {
      records.push(data[start:index].to_owned())
      start = index + separator.length()
      index = start
    } else {
      index += 1
    }
  }
  let trailing = data.length() >= separator.length() &&
    starts_with_at(data, data.length() - separator.length(), separator)
  if start < data.length() {
    records.push(data[start:].to_owned())
  }
  (records, trailing)
}

///|
fn reverse_records(data : Bytes, separator : Bytes, before : Bool) -> Bytes {
  if data.is_empty() {
    return b""
  }
  let (records, trailing) = split_records(data, separator)
  if records.is_empty() {
    return data
  }
  let output : Array[Byte] = []
  let mut index = records.length() - 1
  while index >= 0 {
    if before && (trailing || index != records.length() - 1) {
      output.append(separator.to_array())
    }
    output.append(records[index].to_array())
    if !before && index != 0 {
      output.append(separator.to_array())
    }
    index -= 1
  }
  if !before && trailing {
    output.append(separator.to_array())
  }
  Bytes::from_array(output)
}

///|
fn help_message() -> String {
  let message =
    #|Usage: tac [OPTION]... [FILE]...
    #|
    #|Write each FILE to standard output, last line first.
    #|With no FILE, or when FILE is -, read standard input.
    #|
    #|  -b, --before             Attach the separator before records.
    #|  -s, --separator=STRING   Use STRING instead of newline.
    #|  -r, --regex              Not supported: regular separators need a public
    #|                            regular-expression API with byte semantics.
    #|      --help               Show this help message.
  message
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("before", short='b'),
    @cli.option("separator", short='s'),
    @cli.flag("regex", short='r'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tac: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("regex") {
    @stdio.stderr.write(
      "tac: regular expression separators are not supported by this build\n",
    )
    @sys.exit(2)
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("tac: multiple input files are not supported\n")
    @sys.exit(2)
    return
  }
  let separator = @utf8.encode(parsed.last_value("separator").unwrap_or("\n"))
  if separator.is_empty() {
    @stdio.stderr.write("tac: separator must not be empty\n")
    @sys.exit(2)
    return
  }
  let path = if parsed.operands.is_empty() { "-" } else { parsed.operands[0] }
  let data = try {
    if path == "-" {
      @stdio.stdin.read_all().binary()
    } else {
      @fs.read_file(path).binary()
    }
  } catch {
    err => {
      @stdio.stderr.write("tac: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  @stdio.stdout.write(
    reverse_records(data, separator, parsed.contains("before")),
  )
}
