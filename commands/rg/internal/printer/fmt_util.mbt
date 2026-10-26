///|
fn imin(a : Int32, b : Int32) -> Int32 {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Encodes a string as UTF-8 bytes.
fn utf8_bytes(s : String) -> Bytes {
  let v = @termcolor.ByteVec::new(capacity=s.length() + 1)
  v.extend_string(s)
  v.to_bytes()
}

///|
fn hex_escape(n : Int32) -> String {
  let d = (x : Int32) => {
    (if x < 10 { x + '0' } else { x - 10 + 'a' }).unsafe_to_char().to_string()
  }
  "\\x" + d(n >> 4) + d(n & 0xF)
}

///|
/// Formats a single byte like Rust's `{:?}` of `[byte].as_bstr()`.
fn debug_byte(b : Byte) -> String {
  let s = match b {
    b'\x00' => "\\0"
    b'\t' => "\\t"
    b'\r' => "\\r"
    b'\n' => "\\n"
    b'\\' => "\\\\"
    b'\'' => "\\'"
    b'"' => "\\\""
    _ =>
      if b >= b'\x20' && b <= b'\x7E' {
        b.to_int().unsafe_to_char().to_string()
      } else {
        hex_escape(b.to_int())
      }
  }
  "\"" + s + "\""
}
