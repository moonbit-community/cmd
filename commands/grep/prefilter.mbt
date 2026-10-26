///|
fn Matcher::may_match_block(
  self : Matcher,
  data : BytesView,
  ignore_case : Bool,
) -> Bool {
  match self {
    Fixed(patterns, _, _) =>
      ignore_case ||
      patterns.iter().any(pattern => data.find(pattern) is Some(_))
    Regular(patterns, _, _) =>
      patterns
      .iter()
      .any(pattern => {
        let required = pattern.required_literal()
        required.is_empty() || data.find(required) is Some(_)
      })
  }
}

///|
/// Only skip complete records already inspected for binary input by the refill
/// path. Leave the final fragment for cross-block assembly and error handling.
fn GrepInput::skip_nonmatching(
  self : GrepInput,
  matcher : Matcher,
  ignore_case : Bool,
) -> Unit {
  guard !self.prefiltered else { return }
  self.prefiltered = true
  let remaining = self.bytes[self.position:]
  guard remaining.rev_find(self.delimiter) is Some(last) else { return }
  let complete = remaining[:last + 1]
  if !matcher.may_match_block(complete, ignore_case) {
    self.number += @stream.count_byte(complete, self.delimiter[0]).to_int64()
    self.offset += complete.length().to_int64()
    self.position += complete.length()
  }
}

///|
/// Counting needs neither Record objects nor an async continuation per record.
/// Retain incomplete tails for the same refill/error path as emitted records.
fn GrepInput::count_buffered(
  self : GrepInput,
  matcher : Matcher,
  ignore_case : Bool,
  invert : Bool,
) -> UInt64 {
  let initial = self.position
  let mut count = 0UL
  while self.bytes[self.position:].find(self.delimiter) is Some(relative) {
    let end = self.position + relative
    let matched = matcher.matches_record(
      self.bytes[self.position:end],
      ignore_case,
    )
    if matched != invert {
      count += 1UL
    }
    self.position = end + 1
    self.number += 1L
  }
  self.offset += (self.position - initial).to_int64()
  count
}
