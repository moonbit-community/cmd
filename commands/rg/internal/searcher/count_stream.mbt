///|
// Eligibility is decided before reading. Once a record is discarded there is
// no fallback: only a bounded literal can prove the retained suffix sufficient.
async fn Searcher::stream_literal_count(
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
  guard matcher.literal_overlap(term) is Some(overlap) else { return false }
  guard sink.synchronous_count() is Some(accept) else { return false }
  let mut total = 0L
  if sink.begin(self) {
    let capacity = self.reader_capacity(sink)
    let buffer = FixedArray::make(capacity + overlap, b'\x00')
    let mut carry = 0
    let mut pending = false
    let mut matched = false
    while true {
      let length = reader.read(buffer, carry, capacity)
      if length == 0 {
        if pending && matched {
          accept(1L)
        }
        break
      }
      total += length.to_int64()
      let end = carry + length
      let mut start = 0
      if pending {
        let newline = @memchr.memchr(term, buffer, carry, end)
        let limit = if newline < 0 { end } else { newline + 1 }
        matched = matched || matcher.find_at(buffer, 0, limit, 0) is Some(_)
        if newline < 0 {
          carry = if matched { 0 } else { overlap.min(end) }
          buffer.blit_to(
            buffer,
            src_offset=end - carry,
            dst_offset=0,
            len=carry,
          )
          continue
        }
        if matched {
          accept(1L)
        }
        start = limit
        pending = false
      }
      let newline = @memchr.memrchr(term, buffer, start, end)
      let complete = if newline < 0 { start } else { newline + 1 }
      if complete > start {
        let count = match
          matcher.count_matching_lines(buffer, start, complete, term) {
          Some(count) => count
          None => {
            let mut count = 0L
            let mut line = start
            while line < complete {
              let next = @memchr.memchr(term, buffer, line, complete) + 1
              if matcher.find_at(buffer, line, next, 0) is Some(_) {
                count += 1L
              }
              line = next
            }
            count
          }
        }
        if count > 0L {
          accept(count)
        }
      }
      pending = complete < end
      matched = pending && matcher.find_at(buffer, complete, end, 0) is Some(_)
      carry = if pending && !matched { overlap.min(end - complete) } else { 0 }
      buffer.blit_to(buffer, src_offset=end - carry, dst_offset=0, len=carry)
    }
  }
  sink.finish(self, { byte_count: total, binary_byte_offset: None, })
  true
}
