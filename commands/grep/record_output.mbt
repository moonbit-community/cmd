///|
// Batch complete unadorned records from the current immutable input chunk.
// Adjacent selected records share one copy; partial records retain next().
fn GrepInput::collect_records(
  self : GrepInput,
  matcher : Matcher,
  options : GrepOptions,
  buffer : @buffer.Buffer,
) -> UInt64 {
  guard self.error is None else { return 0UL }
  let mut selected = 0UL
  let mut run_start = -1
  let start = self.position
  let mut at = start
  while self.bytes[at:].find(self.delimiter) is Some(relative) {
    let end = at + relative
    let matched = matcher.matches_record(
      self.bytes[at:end],
      options.ignore_case,
    )
    let keep = if options.invert { !matched } else { matched }
    if keep {
      selected += 1UL
      if run_start < 0 {
        run_start = at
      }
    } else if run_start >= 0 {
      buffer.write_bytes(self.bytes[run_start:at])
      run_start = -1
    }
    at = end + 1
    self.number += 1L
  }
  if run_start >= 0 {
    buffer.write_bytes(self.bytes[run_start:at])
  }
  self.position = at
  self.offset += (at - start).to_int64()
  selected
}
