///|
/// The kind of a syntax or translation error.
pub(all) enum ErrorKind {
  CaptureLimitExceeded
  ClassEscapeInvalid
  ClassRangeInvalid
  ClassRangeLiteral
  ClassUnclosed
  DecimalEmpty
  DecimalInvalid
  EscapeHexEmpty
  EscapeHexInvalid
  EscapeHexInvalidDigit
  EscapeUnexpectedEof
  EscapeUnrecognized
  FlagDanglingNegation
  FlagDuplicate(Span)
  FlagRepeatedNegation(Span)
  FlagUnexpectedEof
  FlagUnrecognized
  GroupNameDuplicate(Span)
  GroupNameEmpty
  GroupNameInvalid
  GroupNameUnexpectedEof
  GroupUnclosed
  GroupUnopened
  NestLimitExceeded(Int32)
  RepetitionCountInvalid
  RepetitionCountDecimalEmpty
  RepetitionCountUnclosed
  RepetitionMissing
  SpecialWordBoundaryUnclosed
  SpecialWordBoundaryUnrecognized
  SpecialWordOrRepetitionUnexpectedEof
  UnicodeClassInvalid
  UnsupportedBackreference
  UnsupportedLookAround
  // Translation errors.
  UnicodeNotAllowed
  InvalidUtf8
  InvalidLineTerminator
  UnicodePropertyNotFound
  UnicodePropertyValueNotFound
  UnicodePerlClassNotFound
  UnicodeCaseUnavailable
} derive(Debug, Eq)

///|
pub fn ErrorKind::message(self : ErrorKind) -> String {
  match self {
    CaptureLimitExceeded =>
      "exceeded the maximum number of capturing groups (4294967295)"
    ClassEscapeInvalid => "invalid escape sequence found in character class"
    ClassRangeInvalid =>
      "invalid character class range, the start must be <= the end"
    ClassRangeLiteral => "invalid range boundary, must be a literal"
    ClassUnclosed => "unclosed character class"
    DecimalEmpty => "decimal literal empty"
    DecimalInvalid => "decimal literal invalid"
    EscapeHexEmpty => "hexadecimal literal empty"
    EscapeHexInvalid => "hexadecimal literal is not a Unicode scalar value"
    EscapeHexInvalidDigit => "invalid hexadecimal digit"
    EscapeUnexpectedEof =>
      "incomplete escape sequence, reached end of pattern prematurely"
    EscapeUnrecognized => "unrecognized escape sequence"
    FlagDanglingNegation => "dangling flag negation operator"
    FlagDuplicate(_) => "duplicate flag"
    FlagRepeatedNegation(_) => "flag negation operator repeated"
    FlagUnexpectedEof => "expected flag but got end of regex"
    FlagUnrecognized => "unrecognized flag"
    GroupNameDuplicate(_) => "duplicate capture group name"
    GroupNameEmpty => "empty capture group name"
    GroupNameInvalid => "invalid capture group character"
    GroupNameUnexpectedEof => "unclosed capture group name"
    GroupUnclosed => "unclosed group"
    GroupUnopened => "unopened group"
    NestLimitExceeded(limit) =>
      "exceed the maximum number of nested parentheses/brackets (\{limit})"
    RepetitionCountInvalid =>
      "invalid repetition count range, the start must be <= the end"
    RepetitionCountDecimalEmpty =>
      "repetition quantifier expects a valid decimal"
    RepetitionCountUnclosed => "unclosed counted repetition"
    RepetitionMissing => "repetition operator missing expression"
    SpecialWordBoundaryUnclosed =>
      "special word boundary assertion is either unclosed or contains an invalid character"
    SpecialWordBoundaryUnrecognized =>
      "unrecognized special word boundary assertion, valid choices are: start, end, start-half or end-half"
    SpecialWordOrRepetitionUnexpectedEof =>
      "found either the beginning of a special word boundary or a bounded repetition on a \\b with an opening brace, but no closing brace"
    UnicodeClassInvalid => "invalid Unicode character class"
    UnsupportedBackreference => "backreferences are not supported"
    UnsupportedLookAround =>
      "look-around, including look-ahead and look-behind, is not supported"
    UnicodeNotAllowed => "Unicode not allowed here"
    InvalidUtf8 => "pattern can match invalid UTF-8"
    InvalidLineTerminator => "invalid line terminator, must be ASCII"
    UnicodePropertyNotFound => "Unicode property not found"
    UnicodePropertyValueNotFound => "Unicode property value not found"
    UnicodePerlClassNotFound =>
      "Unicode-aware Perl class not found (make sure the unicode-perl feature is enabled)"
    UnicodeCaseUnavailable =>
      "Unicode-aware case insensitivity matching is not available (make sure the unicode-case feature is enabled)"
  }
}

///|
fn ErrorKind::aux_span(self : ErrorKind) -> Span? {
  match self {
    FlagDuplicate(s) | FlagRepeatedNegation(s) | GroupNameDuplicate(s) =>
      Some(s)
    _ => None
  }
}

///|
/// An error that occurred while parsing or translating a regex.
pub suberror SyntaxError {
  SyntaxError(kind~ : ErrorKind, pattern~ : String, span~ : Span)
} derive(Debug)

///|
pub fn SyntaxError::kind(self : SyntaxError) -> ErrorKind {
  let SyntaxError(kind~, ..) = self
  kind
}

///|
pub fn SyntaxError::span(self : SyntaxError) -> Span {
  let SyntaxError(span~, ..) = self
  span
}

///|
/// Splits the pattern into lines the same way Rust's `str::lines` does.
fn pattern_lines(pattern : Array[Char]) -> Array[String] {
  let lines = []
  let cur = StringBuilder()
  let mut has = false
  for c in pattern {
    if c == '\n' {
      let s = cur.to_string()
      lines.push(
        if s.has_suffix("\r") {
          s.view(end_offset=s.length() - 1).to_owned()
        } else {
          s
        },
      )
      cur.reset()
      has = false
    } else {
      cur.write_char(c)
      has = true
    }
  }
  if has {
    lines.push(cur.to_string())
  }
  lines
}

///|
fn repeat_char(c : Char, n : Int32) -> String {
  let b = StringBuilder()
  for _ in 0..<n {
    b.write_char(c)
  }
  b.to_string()
}

///|
/// Renders the error in the same format as Rust's regex-syntax.
pub fn SyntaxError::to_string(self : SyntaxError) -> String {
  let SyntaxError(kind~, pattern~, span~) = self
  let chars = pattern.iter().collect()
  let lines = pattern_lines(chars)
  let mut line_count = lines.length()
  if pattern.has_suffix("\n") {
    line_count += 1
  }
  let line_number_width = if line_count <= 1 {
    0
  } else {
    line_count.to_string().length()
  }
  let by_line : Array[Array[Span]] = Array::makei(line_count, _ => [])
  let multi_line : Array[Span] = []
  fn add(s : Span) {
    if s.is_one_line() {
      let i = s.start.line - 1
      if i < by_line.length() {
        by_line[i].push(s)
        by_line[i].sort()
      }
    } else {
      multi_line.push(s)
      multi_line.sort()
    }
  }

  add(span)
  if kind.aux_span() is Some(aux) {
    add(aux)
  }
  let padding = if line_number_width == 0 { 4 } else { 2 + line_number_width }
  let notated = StringBuilder()
  for i, line in lines {
    if line_number_width > 0 {
      let n = (i + 1).to_string()
      notated.write_string(repeat_char(' ', line_number_width - n.length()))
      notated.write_string(n)
      notated.write_string(": ")
    } else {
      notated.write_string("    ")
    }
    notated.write_string(line)
    notated.write_char('\n')
    if i < by_line.length() && by_line[i].length() > 0 {
      notated.write_string(repeat_char(' ', padding))
      let mut pos = 0
      for s in by_line[i] {
        while pos < s.start.column - 1 {
          notated.write_char(' ')
          pos += 1
        }
        let note_len = if s.end.column > s.start.column {
          s.end.column - s.start.column
        } else {
          0
        }
        let n = if note_len < 1 { 1 } else { note_len }
        for _ in 0..<n {
          notated.write_char('^')
          pos += 1
        }
      }
      notated.write_char('\n')
    }
  }
  let out = StringBuilder()
  if pattern.contains("\n") {
    let divider = repeat_char('~', 79)
    out.write_string("regex parse error:\n")
    out.write_string(divider)
    out.write_char('\n')
    out.write_string(notated.to_string())
    out.write_string(divider)
    out.write_char('\n')
    if multi_line.length() > 0 {
      let notes = multi_line.map(s => {
        "on line \{s.start.line} (column \{s.start.column}) through line \{s.end.line} (column \{s.end.column - 1})"
      })
      out.write_string(notes.join("\n"))
      out.write_char('\n')
    }
    out.write_string("error: ")
    out.write_string(kind.message())
  } else {
    out.write_string("regex parse error:\n")
    out.write_string(notated.to_string())
    out.write_string("error: ")
    out.write_string(kind.message())
  }
  out.to_string()
}

///|
pub impl Show for SyntaxError with fn output(self, logger) {
  logger.write_string(self.to_string())
}
