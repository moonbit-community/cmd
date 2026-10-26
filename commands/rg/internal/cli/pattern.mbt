///|
/// An error that occurs when a pattern is not valid UTF-8.
pub suberror InvalidPatternError {
  InvalidPatternError(original~ : String, valid_up_to~ : Int32)
} derive(Debug, Eq)

///|
pub fn InvalidPatternError::valid_up_to(self : InvalidPatternError) -> Int32 {
  let InvalidPatternError(valid_up_to~, ..) = self
  valid_up_to
}

///|
pub fn InvalidPatternError::to_string(self : InvalidPatternError) -> String {
  let InvalidPatternError(original~, valid_up_to~) = self
  "found invalid UTF-8 in pattern at byte offset \{valid_up_to}: \{original} (disable Unicode mode and use hex escape sequences to match arbitrary bytes in a pattern, e.g., '(?-u)\\xFF')"
}

///|
pub impl Show for InvalidPatternError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Converts bytes into a pattern string, failing with a targeted error if
/// they are not valid UTF-8.
pub fn pattern_from_bytes(
  pattern : BytesView,
) -> String raise InvalidPatternError {
  match utf8_valid_up_to(pattern) {
    None => @utf8.decode_lossy(pattern)
    Some(i) =>
      raise InvalidPatternError(original=escape(pattern), valid_up_to=i)
  }
}

///|
/// An error reading patterns from a file or reader.
pub suberror PatternsError {
  PatternsError(String)
} derive(Debug)

///|
pub fn PatternsError::to_string(self : PatternsError) -> String {
  let PatternsError(s) = self
  s
}

///|
pub impl Show for PatternsError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Reads patterns from bytes, one per line. Lines are split on `\n` and a
/// trailing `\r` is stripped (like bstr's `for_byte_line`).
pub fn patterns_from_bytes(data : Bytes) -> Array[String] raise PatternsError {
  let patterns = []
  let mut line_number = 0
  let mut start = 0
  let n = data.length()
  while start < n {
    let mut end = start
    while end < n && data[end] != b'\n' {
      end += 1
    }
    let mut line_end = end
    if line_end > start && data[line_end - 1] == b'\r' {
      line_end -= 1
    }
    line_number += 1
    let line = data[start:line_end]
    let p = pattern_from_bytes(line) catch {
      e => raise PatternsError("\{line_number}: \{e}")
    }
    patterns.push(p)
    start = end + 1
  }
  patterns
}
