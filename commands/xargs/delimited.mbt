///|
priv suberror ArgvBytesBoundary {
  ArgvBytesBoundary
}

///|
priv struct InputItem {
  value : String
  size : Int64
}

///|
fn delimiter_byte(text : String) -> Int32 raise XargsError {
  let bytes = @utf8.encode(text[:])
  if bytes.length() == 1 {
    return bytes[0].to_int()
  }
  if !text.has_prefix("\\") {
    raise XargsError(
      "Invalid input delimiter specification \{text}: the delimiter must be either a single character or an escape sequence starting with \\.",
    )
  }
  if text.length() < 2 {
    return 92
  }
  match text[1] {
    'a' => return 7
    'b' => return 8
    'f' => return 12
    'n' => return 10
    'r' => return 13
    't' => return 9
    'v' => return 11
    '\\' => return 92
    _ => ()
  }
  let hex = text[1] == 'x'
  if !hex && !(text[1] is ('0'..<='9')) {
    raise XargsError(
      "Invalid escape sequence \{text} in input delimiter specification.",
    )
  }
  let base = if hex { 16 } else { 8 }
  let start = if hex { 2 } else { 1 }
  let mut index = start
  while index < text.length() &&
        text[index] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    index += 1
  }
  let negative = index < text.length() && text[index] == '-'
  if index < text.length() && text[index] is ('+' | '-') {
    index += 1
  }
  let digits = index
  let mut value = 0
  while index < text.length() {
    let digit = match text[index] {
      '0'..<='9' => text[index].to_int() - '0'.to_int()
      'a'..<='f' => text[index].to_int() - 'a'.to_int() + 10
      'A'..<='F' => text[index].to_int() - 'A'.to_int() + 10
      _ => break
    }
    if digit >= base {
      break
    }
    value = (value * base + digit).min(256)
    index += 1
  }
  if digits == index {
    index = start
  }
  if value > 255 || (negative && value != 0) {
    raise XargsError(
      "Invalid escape sequence \{text} in input delimiter specification; character values must not exceed \{if hex { "ff" } else { "377" }}.",
    )
  }
  if index < text.length() {
    raise XargsError(
      "Invalid escape sequence \{text} in input delimiter specification; trailing characters \{text[index:]} not recognised.",
    )
  }
  value
}

///|
fn input_item(data : BytesView) -> InputItem raise ArgvBytesBoundary {
  // exec's C argv sees only the prefix preceding an embedded NUL.
  let prefix = if data.find(b"\x00"[:]) is Some(index) {
    data[:index]
  } else {
    data
  }
  let value = @utf8.decode(prefix) catch { _ => raise ArgvBytesBoundary }
  { value, size: data.length().to_int64() + 1L, }
}

///|
async fn delimiter_or_exit(value : String) -> Int32? {
  try delimiter_byte(value) catch {
    XargsError(message) => {
      @stdio.stderr.write("xargs: \{message}\n")
      @sys.exit(1)
      None
    }
  } noraise {
    value => Some(value)
  }
}

///|
async fn confirm_batch(
  channel : &@io.Reader,
  program : String,
  arguments : Array[String],
) -> Bool {
  @stdio.stderr.write([program, ..arguments].map(shell_word).join(" ") + "?...")
  let mut first = true
  let mut accepted = false
  while channel.read_some(max_len=1) is Some(bytes) {
    if first {
      accepted = bytes[0] is (b'y' | b'Y')
      first = false
    }
    if bytes[0] == b'\n' {
      return accepted
    }
  }
  raise XargsError("Failed to read from stdin")
}

///|
fn shell_word(value : String) -> String {
  if !value.is_empty() &&
    value
    .iter()
    .all(c => {
      c
      is ('a'..<='z'
      | 'A'..<='Z'
      | '0'..<='9'
      | '_'
      | '-'
      | '.'
      | '/'
      | ':'
      | '+'
      | '@'
      | '%')
    }) {
    value
  } else {
    "'" + value.replace_all(old="'", new="'\\''") + "'"
  }
}
