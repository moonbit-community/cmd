///|
/// Result of decoding one backslash escape sequence.
priv enum EscOut {
  Out(Array[Byte])
  Stop
  Invalid(String)
}

///|
fn hex_val(c : Char) -> Int32 {
  match c {
    '0'..<='9' => c.to_int() - 0x30
    'a'..<='f' => c.to_int() - 0x61 + 10
    'A'..<='F' => c.to_int() - 0x41 + 10
    _ => -1
  }
}

///|
fn push_char_utf8(out : Array[Byte], c : Char) -> Unit {
  if c.to_int() < 0x80 {
    out.push(c.to_int().to_byte())
  } else {
    for b in @utf8.encode(c.to_string()) {
      out.push(b)
    }
  }
}

///|
fn push_string_utf8(out : Array[Byte], s : String) -> Unit {
  for b in @utf8.encode(s) {
    out.push(b)
  }
}

///|
/// Decode the escape sequence whose backslash sits at `start`. Returns the
/// output and the number of characters consumed (including the backslash).
/// Octal accepts `\NNN` and `\0NNN`, hex `\xHH`, Unicode `\uHHHH`/`\UHHHHHHHH`,
/// and `\c` stops all output. Unknown escapes pass through literally.
fn decode_escape(
  chars : Array[Char],
  start : Int32,
  in_b~ : Bool = false,
) -> (EscOut, Int32) {
  if start + 1 >= chars.length() {
    return (Out([b'\\']), 1)
  }
  let e = chars[start + 1]
  let simple : Int32 = match e {
    'a' => 0x07
    'b' => 0x08
    'e' => 0x1B
    'f' => 0x0C
    'n' => 0x0A
    'r' => 0x0D
    't' => 0x09
    'v' => 0x0B
    '\\' => 0x5C
    '"' => 0x22
    '\'' => 0x27
    _ => -1
  }
  if simple >= 0 {
    return (Out([simple.to_byte()]), 2)
  }
  if e == 'c' {
    return (Stop, 2)
  }
  if e is ('0'..<='7') {
    // FORMAT strings take up to three octal digits total (`\101`, and `\010`
    // leaves a following digit alone). In %b arguments a leading `0` is a
    // marker followed by up to three more digits (`\0102` is one byte), while
    // `\101` still works, matching GNU printf.
    let mut i = start + 1
    if in_b && e == '0' {
      i += 1
    }
    let mut value = 0
    let mut count = 0
    while i < chars.length() && count < 3 && chars[i] is ('0'..<='7') {
      value = value * 8 + (chars[i].to_int() - 0x30)
      i += 1
      count += 1
    }
    return (Out([(value % 256).to_byte()]), i - start)
  }
  if e == 'x' {
    let mut i = start + 2
    let mut value = 0
    let mut count = 0
    while i < chars.length() && count < 2 && hex_val(chars[i]) >= 0 {
      value = value * 16 + hex_val(chars[i])
      i += 1
      count += 1
    }
    if count == 0 {
      return (Invalid("printf: missing hexadecimal number in escape"), 2)
    }
    return (Out([value.to_byte()]), 2 + count)
  }
  if e == 'u' || e == 'U' {
    let need = if e == 'u' { 4 } else { 8 }
    let mut value = 0
    for k in 0..<need {
      let idx = start + 2 + k
      if idx >= chars.length() || hex_val(chars[idx]) < 0 {
        return (Invalid("printf: missing hexadecimal number in escape"), 2)
      }
      value = value * 16 + hex_val(chars[idx])
    }
    if value >= 0xD800 && value <= 0xDFFF {
      // Surrogates are rejected like GNU printf...
      return (
        Invalid("printf: invalid universal character name \\\{e}"),
        2 + need,
      )
    }
    match value.to_char() {
      Some(c) => {
        let out : Array[Byte] = []
        push_char_utf8(out, c)
        (Out(out), 2 + need)
      }
      None => {
        // ...while complete but out-of-range names pass through literally.
        let out : Array[Byte] = []
        out.push(b'\\')
        push_char_utf8(out, e)
        for k in 0..<need {
          push_char_utf8(out, chars[start + 2 + k])
        }
        (Out(out), 2 + need)
      }
    }
  } else {
    // Unknown escape: print backslash and the character literally.
    let out : Array[Byte] = []
    out.push(b'\\')
    push_char_utf8(out, e)
    (Out(out), 2)
  }
}

///|
fn repeat_char(c : Char, n : Int32) -> String {
  let sb = StringBuilder()
  for _ in 0..<n {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// Left-pad `body` with zeros to at least `prec` digits; precision 0 renders
/// the value 0 as an empty string, matching C printf.
fn apply_precision(body : String, prec : Int32?) -> String {
  match prec {
    Some(p) => {
      if body == "0" && p == 0 {
        return ""
      }
      if body.length() >= p {
        body
      } else {
        repeat_char('0', p - body.length()) + body
      }
    }
    None => body
  }
}

///|
/// Assemble sign/prefix + body into a field of `width` characters. With the
/// zero flag, padding zeros go between the prefix and the body.
fn pad_field(
  prefix : String,
  body : String,
  width : Int32?,
  minus : Bool,
  zero : Bool,
) -> String {
  let content = prefix + body
  match width {
    Some(w) =>
      if content.length() >= w {
        content
      } else if minus {
        content + repeat_char(' ', w - content.length())
      } else if zero {
        prefix + repeat_char('0', w - content.length()) + body
      } else {
        repeat_char(' ', w - content.length()) + content
      }
    None => content
  }
}

///|
/// Append raw bytes into `out`, space-padded to `width` bytes.
fn emit_padded_bytes(
  out : Array[Byte],
  bytes : Array[Byte],
  width : Int32?,
  minus : Bool,
) -> Unit {
  let pad = match width {
    Some(w) => if w > bytes.length() { w - bytes.length() } else { 0 }
    None => 0
  }
  if pad > 0 && !minus {
    for _ in 0..<pad {
      out.push(b' ')
    }
  }
  out.append(bytes)
  if pad > 0 && minus {
    for _ in 0..<pad {
      out.push(b' ')
    }
  }
}

///|
fn shell_quote(text : String) -> String {
  @quoting.shell_escape(@utf8.encode(text)[:])
}
