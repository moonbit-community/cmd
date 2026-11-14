///|
const MaxCookieLineBytes = 5000

///|
const MaxCookiePairBytes = 4096

///|
/// Curl's fixed file reader consumes at most 127 bytes per fgets call, appends
/// the prefix before NUL, and waits for a visible LF before admitting a row.
/// An oversized accumulated line ends that file while retaining earlier rows.
fn cookie_file_lines(text : String) -> (Array[String], Bool) {
  let result : Array[String] = []
  let mut position = 0
  let mut line = StringBuilder()
  let mut size = 0
  let mut last = '\u0000'
  while position < text.length() {
    let start = position
    let limit = (start + 127).min(text.length())
    while position < limit {
      let character = text.code_unit_at(position)
      position += 1
      if character == '\n' {
        break
      }
    }
    let chunk = text[start:position]
    let visible = chunk[:chunk.find("\u0000").unwrap_or(chunk.length())]
    if size + visible.length() >= MaxCookieLineBytes {
      return (result, false)
    }
    line.write_view(visible)
    size += visible.length()
    if !visible.is_empty() {
      last = visible.get_char(visible.length() - 1).unwrap()
    }
    if position == text.length() && last != '\n' {
      if size + 1 >= MaxCookieLineBytes {
        return (result, false)
      }
      line.write_char('\n')
      size += 1
      last = '\n'
    }
    if last == '\n' {
      let complete = line.to_string()
      result.push(complete[:complete.length() - 1].to_owned())
      line = StringBuilder()
      size = 0
      last = '\u0000'
    }
  }
  (result, true)
}

///|
/// Parser text uses one U+0000..U+00FF code point per wire byte. It is never
/// encoded as UTF-8 when constructing Cookie fields or persistent jar rows.
fn cookie_text(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_char(byte.to_int().to_char().unwrap())
  }
  out.to_string()
}

///|
fn cookie_bytes(text : String) -> Bytes {
  Bytes::from_array(
    text
    .iter()
    .map(character => {
      guard character.to_int() <= 255 else {
        abort("non-octet cookie parser text")
      }
      character.to_int().to_byte()
    })
    .to_array(),
  )
}

///|
fn cookie_utf8(text : String) -> String {
  @utf8.decode(cookie_bytes(text)) catch {
    _ => text
  }
}
