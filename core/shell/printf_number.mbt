///|
fn printf_blank(char : Char) -> Bool {
  char is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c')
}

///|
fn printf_digit(char : Char) -> Int32 {
  match char {
    '0'..<='9' => char.to_int() - '0'.to_int()
    'a'..<='f' => char.to_int() - 'a'.to_int() + 10
    'A'..<='F' => char.to_int() - 'A'.to_int() + 10
    _ => -1
  }
}

///|
fn printf_character(value : String) -> Int64? {
  if value.has_prefix("'") || value.has_prefix("\"") {
    Some(@utf8.encode(value[1:]).get(0).unwrap_or(0).to_int().to_int64())
  } else {
    None
  }
}

///|
fn printf_integer(value : String, unsigned : Bool) -> (Int64, String?) {
  if value == "" {
    return (0L, None)
  }
  if printf_character(value) is Some(number) {
    return (number, None)
  }
  let chars = value.iter().collect()
  let mut cursor = 0
  while cursor < chars.length() && printf_blank(chars[cursor]) {
    cursor += 1
  }
  let negative = chars.get(cursor) == Some('-')
  if chars.get(cursor) is Some('+' | '-') {
    cursor += 1
  }
  let mut base = 10
  if chars.get(cursor) == Some('0') {
    base = 8
    if chars.get(cursor + 1) is Some('x' | 'X') &&
      chars.get(cursor + 2) is Some(digit) &&
      printf_digit(digit) >= 0 {
      base = 16
      cursor += 2
    }
  }
  let start = cursor
  let mut magnitude = 0UL
  let mut overflow = false
  while cursor < chars.length() {
    let digit = printf_digit(chars[cursor])
    if digit < 0 || digit >= base {
      break
    }
    let digit = digit.to_uint64()
    let radix = base.to_uint64()
    if magnitude > (0xffffffffffffffffUL - digit) / radix {
      overflow = true
    } else {
      magnitude = magnitude * radix + digit
    }
    cursor += 1
  }
  if cursor == start {
    return (0L, Some("expected numeric value"))
  }
  let maximum = if unsigned {
    0xffffffffffffffffUL
  } else if negative {
    0x8000000000000000UL
  } else {
    0x7fffffffffffffffUL
  }
  let range_error = overflow || magnitude > maximum
  let number = if range_error {
    maximum.reinterpret_as_int64()
  } else if negative {
    -magnitude.reinterpret_as_int64()
  } else {
    magnitude.reinterpret_as_int64()
  }
  let warning = if cursor < chars.length() {
    Some("not completely converted")
  } else if range_error {
    Some("Numerical result out of range")
  } else {
    None
  }
  (number, warning)
}

///|
fn printf_float(value : String) -> (@numfmt.Value, String?) {
  if value == "" {
    return (@numfmt.zero(), None)
  }
  if printf_character(value) is Some(number) {
    return (@numfmt.parse_prefix(number.to_string(), Binary64).0, None)
  }
  let (number, consumed, range_error) = @numfmt.parse_prefix(value, Binary64)
  let warning = if consumed == 0 {
    Some("expected numeric value")
  } else if consumed < value.iter().count() {
    Some("not completely converted")
  } else if range_error {
    Some("Numerical result out of range")
  } else {
    None
  }
  (number, warning)
}

///|
fn printf_radix(value : UInt64, radix : UInt64, upper : Bool) -> String {
  if value == 0UL {
    return "0"
  }
  let alphabet = if upper { "0123456789ABCDEF" } else { "0123456789abcdef" }
  let chars : Array[Char] = []
  let mut value = value
  while value > 0UL {
    chars.push(alphabet[(value % radix).to_int()].to_int().unsafe_to_char())
    value = value / radix
  }
  String::from_array(
    Array::makei(chars.length(), i => chars[chars.length() - 1 - i]),
  )
}
