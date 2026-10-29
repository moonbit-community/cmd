///|
/// Scan synchronously until a complete match needs the asynchronous sink.
/// The pending SinkMatch already owns the current event position; fallback
/// must not search again or account for the match twice.
fn Core::buffer_matches(
  self : Core,
  buf : Win,
  accept : (Searcher, SinkMatch) -> Bool raise,
  coalesced : Bool,
) -> Bool raise {
  while self.pos < buf.len {
    let line = if coalesced {
      guard self.next_match_span(buf) is Some(span) else { break }
      span
    } else {
      guard self.find_by_line_fast(buf) is Some(line) else { break }
      self.has_matched = true
      self.count += 1
      self.pos = line.end
      line
    }
    self.count_lines(buf, line.start)
    let mat = self.sink_match
    mat.buf = buf.arr
    mat.buf_start = buf.off
    mat.buf_len = buf.len
    mat.start = line.start
    mat.end = line.end
    mat.absolute_byte_offset = self.absolute_byte_offset + line.start.to_int64()
    mat.line_number = self.line_number
    if !accept(self.searcher, mat) {
      return false
    }
    self.last_line_visited = line.end
    self.after_context_left = 0
    self.has_sunk = true
  }
  true
}

///|
async fn Core::match_by_line_buffered(
  self : Core,
  buf : Win,
  accept : (Searcher, SinkMatch) -> Bool raise,
  coalesced~ : Bool = false,
) -> Bool {
  while !self.buffer_matches(buf, accept, coalesced) {
    if !self.sink.matched(self.searcher, self.sink_match) {
      return false
    }
    self.last_line_visited = self.sink_match.end
    self.after_context_left = 0
    self.has_sunk = true
  }
  if self.has_exceeded_match_limit() {
    return false
  }
  self.pos = buf.len
  true
}
