///|
/// Returns the length of the valid UTF-8 sequence at `b[i:]`, or 0 if the
/// bytes at `i` are not valid UTF-8 (or truncated). Also returns the
/// decoded scalar value.
fn decode_utf8_at(b : BytesView, i : Int32) -> (Int32, Int32) {
  let n = b.length()
  let c = b[i].to_int()
  if c < 0x80 {
    return (1, c)
  }
  let (len, init, min) = if c >= 0xC2 && c <= 0xDF {
    (2, c & 0x1F, 0x80)
  } else if c >= 0xE0 && c <= 0xEF {
    (3, c & 0x0F, 0x800)
  } else if c >= 0xF0 && c <= 0xF4 {
    (4, c & 0x07, 0x10000)
  } else {
    return (0, 0)
  }
  if i + len > n {
    return (0, 0)
  }
  let mut cp = init
  for j in 1..<len {
    let cc = b[i + j].to_int()
    if (cc & 0xC0) != 0x80 {
      return (0, 0)
    }
    cp = (cp << 6) | (cc & 0x3F)
  }
  if cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
    (0, 0)
  } else {
    (len, cp)
  }
}

///|
/// Returns the byte offset of the first invalid UTF-8 byte, or `None` if
/// the bytes are entirely valid UTF-8.
pub fn utf8_valid_up_to(b : BytesView) -> Int32? {
  let mut i = 0
  while i < b.length() {
    let (len, _) = decode_utf8_at(b, i)
    if len == 0 {
      return Some(i)
    }
    i += len
  }
  None
}

///|
fn hex_upper(n : Int32) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
/// Escapes arbitrary bytes into a human readable string, like bstr's
/// `escape_bytes`: printable ASCII (except `\`) and non-ASCII UTF-8 pass
/// through; `\0`, `\n`, `\r`, `\t` and `\\` use special escapes; all other
/// bytes use `\xNN`.
pub fn escape(bytes : BytesView) -> String {
  let buf = StringBuilder()
  let mut i = 0
  while i < bytes.length() {
    let (len, cp) = decode_utf8_at(bytes, i)
    if len > 1 {
      buf.write_char(cp.unsafe_to_char())
      i += len
      continue
    }
    let b = bytes[i].to_int()
    i += 1
    if (b >= 0x21 && b <= 0x5B) || (b >= 0x5D && b <= 0x7E) {
      buf.write_char(b.unsafe_to_char())
    } else {
      buf.write_char('\\')
      match b {
        0 => buf.write_char('0')
        0x0A => buf.write_char('n')
        0x0D => buf.write_char('r')
        0x09 => buf.write_char('t')
        0x5C => buf.write_char('\\')
        _ => {
          buf.write_char('x')
          buf.write_char(hex_upper(b >> 4))
          buf.write_char(hex_upper(b & 0xF))
        }
      }
    }
  }
  buf.to_string()
}

///|
fn hex_value(c : Char) -> Int32? {
  match c {
    '0'..<='9' => Some(c.to_int() - '0'.to_int())
    'a'..<='f' => Some(c.to_int() - 'a'.to_int() + 10)
    'A'..<='F' => Some(c.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn push_char_utf8(out : Buffer, c : Char) -> Unit {
  out.write_bytes(@utf8.encode(c.to_string()))
}

///|
/// Unescapes a string with escape sequences (`\n`, `\t`, `\r`, `\0`, `\\`
/// and `\xNN`) into bytes, like bstr's `unescape_bytes`. Invalid or
/// incomplete escapes unescape as themselves.
pub fn unescape(s : String) -> Bytes {
  let out = Buffer()
  let chars : Array[Char] = s.iter().collect()
  let n = chars.length()
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c != '\\' {
      push_char_utf8(out, c)
      i += 1
      continue
    }
    // Escape.
    if i + 1 >= n {
      out.write_byte(b'\\')
      i += 1
      continue
    }
    let e = chars[i + 1]
    match e {
      '0' => {
        out.write_byte(b'\x00')
        i += 2
      }
      '\\' => {
        out.write_byte(b'\\')
        i += 2
      }
      'r' => {
        out.write_byte(b'\r')
        i += 2
      }
      'n' => {
        out.write_byte(b'\n')
        i += 2
      }
      't' => {
        out.write_byte(b'\t')
        i += 2
      }
      'x' => {
        // HexFirst
        if i + 2 >= n {
          out.write_byte(b'\\')
          out.write_byte(b'x')
          i += 2
          continue
        }
        let h1 = chars[i + 2]
        guard hex_value(h1) is Some(v1) else {
          out.write_byte(b'\\')
          out.write_byte(b'x')
          push_char_utf8(out, h1)
          i += 3
          continue
        }
        if i + 3 >= n {
          out.write_byte(b'\\')
          out.write_byte(b'x')
          push_char_utf8(out, h1)
          i += 3
          continue
        }
        let h2 = chars[i + 3]
        guard hex_value(h2) is Some(v2) else {
          out.write_byte(b'\\')
          out.write_byte(b'x')
          push_char_utf8(out, h1)
          push_char_utf8(out, h2)
          i += 4
          continue
        }
        out.write_byte(((v1 << 4) | v2).to_byte())
        i += 4
      }
      _ => {
        out.write_byte(b'\\')
        push_char_utf8(out, e)
        i += 2
      }
    }
  }
  out.to_bytes()
}
