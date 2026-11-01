///|
/// Parse an octal permission mode, allowing the existing 0o/0O prefix.
pub fn parse_octal_mode(text : String) -> Int32 raise {
  let digits = if text.has_prefix("0o") || text.has_prefix("0O") {
    text[2:]
  } else {
    text[:]
  }
  if digits.is_empty() {
    fail("empty mode")
  }
  let mut value = 0
  for digit in digits {
    if !(digit is ('0'..<='7')) {
      fail("invalid mode")
    }
    value = value * 8 + digit.to_int() - '0'.to_int()
    if value > 0o7777 {
      fail("mode out of range")
    }
  }
  value
}
