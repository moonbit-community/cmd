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
fn is_hex_digest(algorithm : Algorithm, value : String) -> Bool {
  value.length() == algorithm.hex_length() &&
  value.iter().all(c => c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F'))
}

///|
fn parse_record(algorithm : Algorithm, line : String) -> (String, String)? {
  let escaped = line.has_prefix("\\")
  let record = if escaped { line[1:].to_owned() } else { line }
  let length = algorithm.hex_length()
  if record.length() <= length + 2 ||
    record[length] != ' ' ||
    !(record[length + 1] is (' ' | '*')) ||
    !is_hex_digest(algorithm, record[0:length].to_owned()) {
    return None
  }
  let encoded_name = record[length + 2:].to_owned()
  let name = if escaped {
    match decode_filename(encoded_name) {
      Some(name) => name
      None => return None
    }
  } else {
    encoded_name
  }
  if name.contains("\u0000") {
    return None
  }
  Some((record[0:length].to_owned().to_lower(), name))
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
