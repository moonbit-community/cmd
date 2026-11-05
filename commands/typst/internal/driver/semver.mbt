///|
/// The value parser of the version of `update`: `semver::Version::from_str`
/// (semver 1.0.25), with its error messages.
fn parse_semver(v : String) -> Unit raise CliError {
  parse_semver_version(v) catch {
    @kit.StrError(msg) =>
      raise Invalid("invalid value '\{v}' for '[VERSION]': \{msg}")
  }
}

///|
/// The semver crate's `Position` display names.
fn semver_position(pos : Int32) -> String {
  match pos {
    0 => "major version number"
    1 => "minor version number"
    2 => "patch version number"
    3 => "pre-release identifier"
    _ => "build metadata"
  }
}

///|
/// The semver crate's `QuotedChar` (Rust's `Debug` for a `char`).
fn semver_quoted(c : Char) -> String {
  match c {
    '\u{0}' => "'\\0'"
    '\'' => "'\\''"
    '\\' => "'\\\\'"
    '\n' => "'\\n'"
    '\r' => "'\\r'"
    '\t' => "'\\t'"
    _ => "'\{c}'"
  }
}

///|
/// `semver::Version::from_str` (only the validation).
fn parse_semver_version(text : String) -> Unit raise @kit.StrError {
  if text == "" {
    raise @kit.StrError("empty string, expected a semver version")
  }
  let chars = text.to_array()
  let mut i = 0
  let numeric = (pos : Int32) => {
    let start = i
    let mut value = 0UL
    while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
      if value == 0UL && i > start {
        raise @kit.StrError("invalid leading zero in \{semver_position(pos)}")
      }
      let digit = (chars[i].to_int() - '0'.to_int()).to_uint64()
      if value > (18446744073709551615UL - digit) / 10UL {
        raise @kit.StrError("value of \{semver_position(pos)} exceeds u64::MAX")
      }
      value = value * 10UL + digit
      i += 1
    }
    if i == start {
      if i < chars.length() {
        raise @kit.StrError(
          "unexpected character \{semver_quoted(chars[i])} while parsing \{semver_position(pos)}",
        )
      }
      raise @kit.StrError(
        "unexpected end of input while parsing \{semver_position(pos)}",
      )
    }
  }
  let dot = (pos : Int32) => {
    if i < chars.length() && chars[i] == '.' {
      i += 1
    } else if i < chars.length() {
      raise @kit.StrError(
        "unexpected character \{semver_quoted(chars[i])} after \{semver_position(pos)}",
      )
    } else {
      raise @kit.StrError(
        "unexpected end of input while parsing \{semver_position(pos)}",
      )
    }
  }
  // `identifier`: returns whether it is empty.
  let identifier = (pos : Int32) => {
    let begin = i
    let mut segment_start = i
    let mut has_nondigit = false
    while true {
      let c = if i < chars.length() { Some(chars[i]) } else { None }
      match c {
        Some(c) if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '-' => {
          has_nondigit = true
          i += 1
        }
        Some(c) if c >= '0' && c <= '9' => i += 1
        boundary => {
          let segment_len = i - segment_start
          if segment_len == 0 {
            if i == begin && boundary != Some('.') {
              return true
            }
            raise @kit.StrError(
              "empty identifier segment in \{semver_position(pos)}",
            )
          }
          if pos == 3 &&
            segment_len > 1 &&
            !has_nondigit &&
            chars[segment_start] == '0' {
            raise @kit.StrError(
              "invalid leading zero in \{semver_position(pos)}",
            )
          }
          if boundary == Some('.') {
            i += 1
            segment_start = i
            has_nondigit = false
          } else {
            return false
          }
        }
      }
    }
    false
  }
  numeric(0)
  dot(0)
  numeric(1)
  dot(1)
  numeric(2)
  let mut pos = 2
  if i < chars.length() && chars[i] == '-' {
    i += 1
    pos = 3
    if identifier(3) {
      raise @kit.StrError("empty identifier segment in \{semver_position(3)}")
    }
  }
  if i < chars.length() && chars[i] == '+' {
    i += 1
    pos = 4
    if identifier(4) {
      raise @kit.StrError("empty identifier segment in \{semver_position(4)}")
    }
  }
  if i < chars.length() {
    raise @kit.StrError(
      "unexpected character \{semver_quoted(chars[i])} after \{semver_position(pos)}",
    )
  }
}
