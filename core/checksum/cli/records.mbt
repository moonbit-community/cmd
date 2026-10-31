///|
fn encode_filename(name : String) -> (String, Bool) {
  let output = StringBuilder()
  let mut escaped = false
  for char in name {
    match char {
      '\\' => {
        output.write_string("\\\\")
        escaped = true
      }
      '\n' => {
        output.write_string("\\n")
        escaped = true
      }
      '\r' => {
        output.write_string("\\r")
        escaped = true
      }
      _ => output.write_char(char)
    }
  }
  (output.to_string(), escaped)
}

///|
fn decode_filename(value : String) -> String? {
  let chars : Array[Char] = value.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '\\' {
      output.write_char(chars[index])
      index += 1
    } else if index + 1 >= chars.length() {
      return None
    } else {
      match chars[index + 1] {
        '\\' => output.write_char('\\')
        'n' => output.write_char('\n')
        'r' => output.write_char('\r')
        _ => return None
      }
      index += 2
    }
  }
  Some(output.to_string())
}

///|
fn format_record(
  digest : String,
  name : String,
  binary : Bool,
  zero : Bool,
) -> String {
  let marker = if binary { "*" } else { " " }
  if zero {
    "\{digest} \{marker}\{name}\u0000"
  } else {
    let (encoded, escaped) = encode_filename(name)
    let prefix = if escaped { "\\" } else { "" }
    "\{prefix}\{digest} \{marker}\{encoded}\n"
  }
}
