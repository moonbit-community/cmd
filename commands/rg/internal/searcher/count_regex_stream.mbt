///|
// Strategy: rg-regex-probe-replay
// Count-only text mode permits discarding records once a bounded, resumable
// matcher is ready. Declined probes replay decoded bytes through the old path.
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
  let probe = self.line_buffer.buf
  let mut length = 0
  let mut ended = false
  let mut terminated = false
  // Retained allocation belongs to prior inputs, not to this search's policy.
  while length < capacity {
    let size = reader.read(probe, length, capacity - length)
    if size == 0 {
      ended = true
      break
    }
    terminated = @memchr.memchr(term, probe, length, length + size) >= 0
    length += size
    if terminated {
      break
    }
  }
  // A prefix match only declines the optimization; it never supplies a result.
  // This avoids building an expensive plan when early boolean search is cheap.
  let counter = if !terminated &&
    length == capacity &&
    !@matcher.is_match_at(matcher, probe, 0, length.min(65536), 0) {
    matcher.stream_counter(term)
  } else {
    None
  }
  guard counter is Some(counter) else {
    ReadByLine::new(self, matcher, reader, sink).run(
      entry=Replay(length, ended),
    )
    return true
  }
  let initial = counter(probe, 0, length, false)
  if initial > 0L {
    accept(initial)
  }
  let mut total = length.to_int64()
  let buffer = probe
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
