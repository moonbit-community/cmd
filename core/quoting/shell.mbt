///|
fn compatible(byte : Byte) -> Bool {
  byte
  is (b'0'..<=b'9'
  | b'A'..<=b'Z'
  | b'a'..<=b'z'
  | b'%'
  | b'+'
  | b','
  | b'-'
  | b'.'
  | b'/'
  | b':'
  | b']'
  | b'_'
  | b'@'
  | b' '
  | b'\'')
}

///|
fn ascii_text(bytes : BytesView) -> String {
  let output = StringBuilder()
  for byte in bytes {
    output.write_char(byte.to_int().unsafe_to_char())
  }
  output.to_string()
}

///|
/// GNU C-profile shell-escape quoting of bytes. Force selects always-quoted
/// output; colon additionally quotes the colon used by filename diagnostics.
pub fn shell_escape(
  bytes : BytesView,
  force~ : Bool = false,
  colon~ : Bool = false,
) -> String {
  let mut quote = force || bytes.is_empty()
  let mut apostrophe = false
  let mut all_compatible = true
  for index, byte in bytes {
    if !compatible(byte) {
      all_compatible = false
    }
    if byte == b'\'' {
      apostrophe = true
    }
    let literal = (
        (compatible(byte) && byte != b' ' && byte != b'\'') ||
        (index > 0 && byte is (b'#' | b'~')) ||
        (bytes.length() > 1 && byte is (b'{' | b'}'))
      ) &&
      !(colon && byte == b':')
    if !literal {
      quote = true
    }
  }
  if !quote {
    return ascii_text(bytes)
  }
  if apostrophe && all_compatible {
    return "\"" + ascii_text(bytes) + "\""
  }
  let output = StringBuilder()
  output.write_char('\'')
  let mut escape = false
  for byte in bytes {
    if byte < 0x20 || byte >= 0x7F {
      if !escape {
        output.write_string("'$'")
        escape = true
      }
      output.write_char('\\')
      let simple = match byte {
        0x07 => Some('a')
        0x08 => Some('b')
        0x09 => Some('t')
        0x0A => Some('n')
        0x0B => Some('v')
        0x0C => Some('f')
        0x0D => Some('r')
        _ => None
      }
      match simple {
        Some(character) => output.write_char(character)
        None => {
          let value = byte.to_int()
          output.write_char((0x30 + value / 64).unsafe_to_char())
          output.write_char((0x30 + value / 8 % 8).unsafe_to_char())
          output.write_char((0x30 + value % 8).unsafe_to_char())
        }
      }
    } else if byte == b'\'' {
      output.write_string("'\\''")
      escape = false
    } else {
      if escape {
        output.write_string("''")
        escape = false
      }
      output.write_char(byte.to_int().unsafe_to_char())
    }
  }
  output.write_char('\'')
  output.to_string()
}
