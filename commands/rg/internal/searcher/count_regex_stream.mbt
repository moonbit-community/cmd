///|
// Strategy: rg-regex-probe-replay
// Complete records keep the ordinary count path. A full unfinished record
// prepares a bounded counter, independent of its position or prefix matches.
async fn Searcher::stream_regex_count(
  self : Searcher,
  matcher : &@matcher.Matcher,
  reader : &Reader,
  sink : &Sink,
) -> Bool {
  guard self.config.stream_count_term() is Some(term) else { return false }
  guard matcher.stream_count_candidate(term) else { return false }
  guard sink.synchronous_count() is Some(accept) else { return false }
  if !sink.begin(self) {
    sink.finish(self, { byte_count: 0L, binary_byte_offset: None, })
    return true
  }
  let capacity = self.reader_capacity(sink)
  if self.line_buffer.capacity != capacity {
    self.line_buffer = self.config.line_buffer(capacity~)
  }
  self.line_buffer.clear()
  let buffer = self.line_buffer.buf
  let ordinary = ReadByLine::new(self, matcher, reader, sink)
  let mut length = 0
  while length < capacity {
    let size = reader.read(buffer, length, capacity - length)
    if size == 0 {
      ordinary.run(entry=Replay(length, true))
      return true
    }
    let last = @memchr.memrchr(term, buffer, length, length + size)
    length += size
    if last >= 0 {
      self.line_buffer.end = length
      self.line_buffer.last_lineterm = last + 1
      if !ordinary.core.match_by_line(ordinary.win()) {
        self.line_buffer.consume(ordinary.core.pos)
        ordinary.core.finish(self.line_buffer.absolute_byte_offset, None)
        return true
      }
      self.line_buffer.consume(ordinary.core.roll(ordinary.win()))
      self.line_buffer.roll()
      length = self.line_buffer.end
    }
  }
  // No bytes are discarded until the complete plan passes its construction
  // budget. Unsupported assertions and exhausted plans replay the exact tail.
  guard matcher.stream_counter(term) is Some(counter) else {
    ordinary.run(entry=Replay(length, false))
    return true
  }
  let initial = counter(buffer, 0, length, false)
  if initial > 0L {
    accept(initial)
  }
  let mut total = self.line_buffer.absolute_byte_offset + length.to_int64()
  for ;; {
    let length = reader.read(buffer, 0, capacity)
    let count = counter(buffer, 0, length, length == 0)
    if count > 0L {
      accept(count)
    }
    total += length.to_int64()
    if length == 0 {
      break
    }
  }
  sink.finish(self, { byte_count: total, binary_byte_offset: None, })
  true
}
