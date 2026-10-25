///|
/// GNU locale-quoting style under the fixed C byte profile.
pub fn locale_quote(bytes : BytesView) -> String {
  let output = StringBuilder()
  output.write_char('\'')
  for byte in bytes {
    let escape = match byte {
      0 => Some('0')
      7 => Some('a')
      8 => Some('b')
      9 => Some('t')
      10 => Some('n')
      11 => Some('v')
      12 => Some('f')
      13 => Some('r')
      b'\'' => Some('\'')
      b'\\' => Some('\\')
      _ => None
    }
    match escape {
      Some(character) => {
        output.write_char('\\')
        output.write_char(character)
      }
      None => {
        let code = byte.to_int()
        if byte >= b' ' && byte <= b'~' {
          output.write_char(code.unsafe_to_char())
        } else {
          output.write_char('\\')
          output.write_char((0x30 + code / 64).unsafe_to_char())
          output.write_char((0x30 + code / 8 % 8).unsafe_to_char())
          output.write_char((0x30 + code % 8).unsafe_to_char())
        }
      }
    }
  }
  output.write_char('\'')
  output.to_string()
}
