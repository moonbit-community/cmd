///|
// Count-only matching needs neither match starts nor greedy match endpoints.
// Stop transitions after the first hit and skip to the next record boundary.
pub fn RecordBoolean::count_lines(
  self : RecordBoolean,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
  term : Byte,
  pre? : Prefilter,
) -> Int64 {
  let mut count = 0L
  let mut at = start
  let transitions = self.transitions
  let classes = self.classes
  while at < end {
    // Retain the mandatory-literal jump throughout the block. A dense prefix
    // must not force a sparse tail through the byte-at-a-time DFA.
    if pre is Some(filter) {
      let candidate = filter.find_span(hay, at, end)
      if candidate == NO_SPAN {
        break
      }
      let previous = @memchr.memrchr(term, hay, at, span_start(candidate))
      if previous >= 0 {
        at = previous + 1
      }
    }
    let next_term = @memchr.memchr(term, hay, at, end)
    let line_end = if next_term < 0 { end } else { next_term }
    let mut state = self.start
    let mut matched = false
    for i in at..<line_end {
      let next = transitions[state + classes[hay[i].to_int()]]
      if next >= MATCH_TAG {
        matched = true
        break
      }
      state = next
    }
    if matched || transitions[state + self.stride - 1] >= MATCH_TAG {
      count += 1L
    }
    at = if next_term < 0 { end } else { line_end + 1 }
  }
  count
}
