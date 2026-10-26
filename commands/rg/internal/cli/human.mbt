///|
/// An error that occurs when parsing a human readable size description.
pub suberror ParseSizeError {
  InvalidFormat(String)
  InvalidInt(String, String)
  Overflow(String)
} derive(Debug, Eq)

///|
pub fn ParseSizeError::to_string(self : ParseSizeError) -> String {
  match self {
    InvalidFormat(original) =>
      "invalid format for size '\{original}', which should be a non-empty sequence of digits followed by an optional 'K', 'M' or 'G' suffix"
    InvalidInt(original, err) =>
      "invalid integer found in size '\{original}': \{err}"
    Overflow(original) => "size too big in '\{original}'"
  }
}

///|
pub impl Show for ParseSizeError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Parses a human readable size like `2M` into a number of bytes. Supported
/// suffixes are `K`, `M` and `G`.
pub fn parse_human_readable_size(size : String) -> UInt64 raise ParseSizeError {
  let chars : Array[Char] = size.iter().collect()
  let mut digits_end = 0
  while digits_end < chars.length() &&
        chars[digits_end] >= '0' &&
        chars[digits_end] <= '9' {
    digits_end += 1
  }
  if digits_end == 0 {
    raise InvalidFormat(size)
  }
  let max = 0xFFFFFFFFFFFFFFFFUL
  let mut value : UInt64 = 0
  for i in 0..<digits_end {
    let d = (chars[i].to_int() - '0'.to_int()).to_uint64()
    if value > (max - d) / 10 {
      raise InvalidInt(size, "number too large to fit in target type")
    }
    value = value * 10 + d
  }
  let suffix = String::from_array(chars[digits_end:])
  if suffix.is_empty() {
    return value
  }
  let shift = match suffix {
    "K" => 10
    "M" => 20
    "G" => 30
    _ => raise InvalidFormat(size)
  }
  if value > max >> shift {
    raise Overflow(size)
  }
  value << shift
}
