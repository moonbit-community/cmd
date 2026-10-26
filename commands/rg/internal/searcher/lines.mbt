///|
/// Returns the index of the first occurrence of `b` in `buf[start:end]`.
pub fn find_byte(
  buf : FixedArray[Byte],
  b : Byte,
  start : Int32,
  end : Int32,
) -> Int32? {
  let i = @memchr.memchr(b, buf, start, end)
  if i < 0 {
    None
  } else {
    Some(i)
  }
}

///|
/// Returns the index of the last occurrence of `b` in `buf[start:end]`.
pub fn rfind_byte(
  buf : FixedArray[Byte],
  b : Byte,
  start : Int32,
  end : Int32,
) -> Int32? {
  let i = @memchr.memrchr(b, buf, start, end)
  if i < 0 {
    None
  } else {
    Some(i)
  }
}

///|
/// Steps through the lines of `buf[off + pos : off + end]`, yielding line
/// ranges relative to `off`. Lines include their terminators.
pub struct LineStep {
  line_term : Byte
  priv mut pos : Int32
  priv end : Int32
  priv mut line_start : Int32
  priv mut line_end : Int32
}

///|
pub fn LineStep::new(line_term : Byte, start : Int32, end : Int32) -> LineStep {
  { line_term, pos: start, end, line_start: start, line_end: start, }
}

///|
/// Advances to the next line, returning false when there are no more. The
/// line is then `line_start()..line_end()` (relative to `off`). Unlike
/// `next`, this doesn't allocate.
pub fn LineStep::advance(
  self : LineStep,
  buf : FixedArray[Byte],
  off : Int32,
) -> Bool {
  if self.pos >= self.end {
    return false
  }
  let i = @memchr.memchr(self.line_term, buf, off + self.pos, off + self.end)
  self.line_start = self.pos
  self.line_end = if i < 0 { self.end } else { i - off + 1 }
  self.pos = self.line_end
  true
}

///|
/// The start of the current line (see `advance`).
pub fn LineStep::line_start(self : LineStep) -> Int32 {
  self.line_start
}

///|
/// The end of the current line (see `advance`).
pub fn LineStep::line_end(self : LineStep) -> Int32 {
  self.line_end
}

///|
/// Returns the next line as a range relative to `off`.
pub fn LineStep::next(
  self : LineStep,
  buf : FixedArray[Byte],
  off : Int32,
) -> @matcher.Match? {
  if self.advance(buf, off) {
    Some({ start: self.line_start, end: self.line_end, })
  } else {
    None
  }
}

///|
/// Splits `bytes` into lines (including terminators).
pub fn lines_of(bytes : Bytes, line_term : Byte) -> Array[Bytes] {
  let buf = bytes.to_fixedarray()
  let step = LineStep::new(line_term, 0, buf.length())
  let out = []
  while step.next(buf, 0) is Some(m) {
    out.push(bytes[m.start:m.end].to_owned())
  }
  out
}

///|
/// Counts the occurrences of `line_term` in `buf[start:end]`.
pub fn count_lines(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  line_term : Byte,
) -> Int64 {
  @memchr.count(line_term, buf, start, end).to_int64()
}

///|
/// Returns the end of `buf[start:end]` with any trailing line terminator
/// removed.
pub fn without_terminator(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  line_term : @matcher.LineTerminator,
) -> Int32 {
  match line_term {
    CRLF =>
      if end - start >= 2 && buf[end - 2] == b'\r' && buf[end - 1] == b'\n' {
        end - 2
      } else {
        end
      }
    Byte(b) => if end - start >= 1 && buf[end - 1] == b { end - 1 } else { end }
  }
}

///|
/// Returns the range of the lines containing `range` within the window
/// `buf[off:off+len]`. All ranges are relative to `off`.
pub fn locate(
  buf : FixedArray[Byte],
  off : Int32,
  len : Int32,
  line_term : Byte,
  range : @matcher.Match,
) -> @matcher.Match {
  let line_start = match rfind_byte(buf, line_term, off, off + range.start) {
    Some(i) => i - off + 1
    None => 0
  }
  let line_end = if range.end > line_start &&
    buf[off + range.end - 1] == line_term {
    range.end
  } else {
    match find_byte(buf, line_term, off + range.end, off + len) {
      Some(i) => i - off + 1
      None => len
    }
  }
  { start: line_start, end: line_end, }
}

///|
/// Returns the start offset (relative to `off`) of the `count + 1`th line
/// preceding the end of `buf[off:off+len]`.
pub fn preceding(
  buf : FixedArray[Byte],
  off : Int32,
  len : Int32,
  line_term : Byte,
  count : Int32,
) -> Int32 {
  let mut pos = len
  let mut count = count
  if pos == 0 {
    return 0
  } else if buf[off + pos - 1] == line_term {
    pos -= 1
  }
  while true {
    match rfind_byte(buf, line_term, off, off + pos) {
      None => return 0
      Some(abs) => {
        let i = abs - off
        if count == 0 {
          return i + 1
        } else if i == 0 {
          return 0
        }
        count -= 1
        pos = i
      }
    }
  }
  0
}
