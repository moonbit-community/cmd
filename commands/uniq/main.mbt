///|
priv suberror CliError {
  CliError(String)
}

///|
fn pad_left(text : String, width : Int) -> String {
  let sb = StringBuilder()
  for _ in 0..<(width - text.length()) {
    sb.write_char(' ')
  }
  sb.write_string(text)
  sb.to_string()
}

///|
fn parse_count(text : String, option : String) -> Int raise CliError {
  let count = @string.parse_int(text) catch {
    _ => raise CliError("uniq: invalid number of \{option}: '\{text}'")
  }
  if count < 0 {
    raise CliError("uniq: invalid number of \{option}: '\{text}'")
  }
  count
}

///|
fn is_blank(byte : Byte) -> Bool {
  byte is (b' ' | b'\t')
}

///|
fn comparison_key(
  line : Bytes,
  skip_fields : Int,
  skip_chars : Int,
  check_chars : Int?,
  ignore_case : Bool,
) -> Bytes {
  let mut start = 0
  for _ in 0..<skip_fields {
    while start < line.length() && is_blank(line[start]) {
      start += 1
    }
    while start < line.length() && !is_blank(line[start]) {
      start += 1
    }
  }
  start = Int::min(line.length(), start + skip_chars)
  let end = match check_chars {
    Some(width) => Int::min(line.length(), start + width)
    None => line.length()
  }
  if !ignore_case {
    return line[start:end].to_owned()
  }
  let folded : Array[Byte] = []
  for byte in line[start:end] {
    let value = byte.to_int()
    folded.push(
      if value >= 0x41 && value <= 0x5A {
        (value + 0x20).to_byte()
      } else {
        byte
      },
    )
  }
  Bytes::from_array(folded)
}

///|
async fn write_group(
  line : Bytes,
  count : Int,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
  delimiter : Byte,
) -> Unit {
  let selected = if only_repeated && only_unique {
    false
  } else if only_repeated {
    count > 1
  } else if only_unique {
    count == 1
  } else {
    true
  }
  if selected {
    if show_count {
      @stdio.stdout.write(pad_left(count.to_string(), 7) + " ")
    }
    @stdio.stdout.write(line)
    @stdio.stdout.write(if delimiter is b'\x00' { b"\x00" } else { b"\n" })
  }
}

///|
async fn process_reader(
  reader : &@io.Reader,
  show_count : Bool,
  only_repeated : Bool,
  only_unique : Bool,
  ignore_case : Bool,
  skip_fields : Int,
  skip_chars : Int,
  check_chars : Int?,
  delimiter : Byte,
) -> Unit {
  let scanner = @stream.LineScanner::new(reader, delimiter~)
  let mut previous : Bytes? = None
  let mut previous_key : Bytes? = None
  let mut count = 0
  while scanner.next() is Some(record) {
    let key = comparison_key(
      record.data,
      skip_fields,
      skip_chars,
      check_chars,
      ignore_case,
    )
    match (previous, previous_key) {
      (Some(_), Some(old_key)) if old_key == key => count += 1
      (Some(old), _) => {
        write_group(
          old, count, show_count, only_repeated, only_unique, delimiter,
        )
        previous = Some(record.data)
        previous_key = Some(key)
        count = 1
      }
      _ => {
        previous = Some(record.data)
        previous_key = Some(key)
        count = 1
      }
    }
  }
  if previous is Some(value) {
    write_group(value, count, show_count, only_repeated, only_unique, delimiter)
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("count", short='c'),
    @cli.flag("repeated", short='d'),
    @cli.flag("unique", short='u'),
    @cli.flag("ignore-case", short='i'),
    @cli.option("skip-fields", short='f'),
    @cli.option("skip-chars", short='s'),
    @cli.option("check-chars", short='w'),
    @cli.flag("zero-terminated", short='z'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("uniq: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: uniq [-cduiz] [-f FIELDS] [-s CHARS] [-w CHARS] [FILE]\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("uniq: extra operand: '\{parsed.operands[1]}'\n")
    @sys.exit(2)
    return
  }
  let (skip_fields, skip_chars, check_chars) = try {
    let fields = match parsed.last_value("skip-fields") {
      Some(text) => parse_count(text, "fields")
      None => 0
    }
    let chars = match parsed.last_value("skip-chars") {
      Some(text) => parse_count(text, "characters")
      None => 0
    }
    let width = match parsed.last_value("check-chars") {
      Some(text) => Some(parse_count(text, "characters"))
      None => None
    }
    (fields, chars, width)
  } catch {
    CliError(message) => {
      @stdio.stderr.write(message + "\n")
      @sys.exit(2)
      return
    }
  }
  let delimiter : Byte = if parsed.contains("zero-terminated") {
    b'\x00'
  } else {
    b'\n'
  }
  let path = if parsed.operands.is_empty() { "-" } else { parsed.operands[0] }
  try {
    if path == "-" {
      process_reader(
        @stdio.stdin,
        parsed.contains("count"),
        parsed.contains("repeated"),
        parsed.contains("unique"),
        parsed.contains("ignore-case"),
        skip_fields,
        skip_chars,
        check_chars,
        delimiter,
      )
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      process_reader(
        file,
        parsed.contains("count"),
        parsed.contains("repeated"),
        parsed.contains("unique"),
        parsed.contains("ignore-case"),
        skip_fields,
        skip_chars,
        check_chars,
        delimiter,
      )
    }
  } catch {
    err => {
      @stdio.stderr.write("uniq: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
