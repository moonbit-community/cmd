///|
// Count-only text mode permits discarding records once a bounded, resumable
// matcher is ready. Declined probes replay decoded bytes through the old path.
async fn Searcher::stream_regex_count(
  self : Searcher,
  matcher : &@matcher.Matcher,
  reader : &Reader,
  sink : &Sink,
) -> Bool {
  let config = self.config
  guard !config.multi_line &&
    !config.invert_match &&
    config.max_matches is None &&
    config.max_context() == 0 &&
    !config.passthru &&
    !config.stop_on_nonmatch &&
    config.heap_limit is None &&
    config.binary is BinaryNone &&
    config.line_term is Byte(term) else {
    return false
  }
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
  while length < probe.length() {
    let size = reader.read(probe, length, probe.length() - length)
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
    length == probe.length() &&
    !@matcher.is_match_at(matcher, probe, 0, length.min(65536), 0) {
    matcher.stream_counter(term)
  } else {
    None
  }
  guard counter is Some(counter) else {
    self.line_buffer.end = length
    self.line_buffer.last_lineterm = if ended {
      length
    } else {
      let last = @memchr.memrchr(term, probe, 0, length)
      if last < 0 {
        0
      } else {
        last + 1
      }
    }
    ReadByLine::new(self, matcher, reader, sink).run(
      begun=true,
      prefetched=true,
      ended~,
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
    let length = reader.read(buffer, 0, buffer.length())
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
