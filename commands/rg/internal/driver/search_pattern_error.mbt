///|
priv suberror SearchPatternError {
  Regex(String)
  NotAllowed(String)
  InvalidLineTerminator(Byte)
  Banned(Byte)
} derive(Debug)

///|
/// Renders a string like Rust's `{:?}` for `str`.
fn rust_debug_str(s : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in s {
    match c {
      '\t' => buf.write_string("\\t")
      '\r' => buf.write_string("\\r")
      '\n' => buf.write_string("\\n")
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\u{0}' => buf.write_string("\\0")
      _ =>
        if c.to_int() < 0x20 || c.to_int() == 0x7F {
          buf.write_string("\\u{\{c.to_int().to_string(radix=16)}}")
        } else {
          buf.write_char(c)
        }
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
/// Renders bytes like bstr's `{:?}` implementation.
fn bstr_debug(bytes : Bytes) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  let s = @utf8.decode_lossy(bytes)
  for c in s {
    let n = c.to_int()
    if c == '\u{0}' {
      buf.write_string("\\0")
    } else if c == '\u{FFFD}' {
      buf.write_char(c)
    } else if (n >= 0x01 && n <= 0x08) ||
      n == 0x0B ||
      n == 0x0C ||
      (n >= 0x0E && n <= 0x19) ||
      n == 0x7F {
      let h = n.to_string(radix=16)
      buf.write_string("\\x" + (if h.length() < 2 { "0" + h } else { h }))
    } else {
      match c {
        '\t' => buf.write_string("\\t")
        '\r' => buf.write_string("\\r")
        '\n' => buf.write_string("\\n")
        '\\' => buf.write_string("\\\\")
        '"' => buf.write_string("\\\"")
        '\'' => buf.write_string("\\'")
        _ => buf.write_char(c)
      }
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn SearchPatternError::to_string(self : SearchPatternError) -> String {
  match self {
    Regex(s) => s
    NotAllowed(lit) =>
      "the literal \{rust_debug_str(lit)} is not allowed in a regex"
    InvalidLineTerminator(b) =>
      "line terminators must be ASCII, but \{bstr_debug(Bytes::make(1, b))} is not"
    Banned(b) =>
      "pattern contains \{bstr_debug(Bytes::make(1, b))} but it is impossible to match"
  }
}

///|
impl Show for SearchPatternError with fn output(self, logger) {
  logger.write_string(self.to_string())
}
