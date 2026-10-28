///|
fn Matcher::may_match_block(
  self : Matcher,
  data : BytesView,
  ignore_case : Bool,
) -> Bool {
  match self {
    ManyFixed(set) => ignore_case || set.matches(data)
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
  if matcher is Regular([pattern], false, false) {
    let remaining = self.bytes[self.position:]
    if remaining.rev_find(self.delimiter) is Some(last) {
      let complete = remaining[:last + 1]
      if pattern.count_records(complete, self.delimiter[0])
        is Some((matched, records)) {
        self.position += complete.length()
        self.offset += complete.length().to_int64()
        self.number += records.to_int64()
        return (if invert { records - matched } else { matched }).to_uint64()
      }
    }
  }
  if !ignore_case &&
    matcher is ManyFixed(set) &&
    !set.contains_byte(self.delimiter[0]) {
    return self.count_literals(set, invert)
  }
  if !ignore_case &&
    matcher is Fixed([literal], false, false) &&
    literal.find(self.delimiter) is None {
    return self.count_literal(literal, invert)
  }
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

///|
/// A fixed hit identifies a record directly. Skip the rest of that record so
/// repeated hits count once; a literal containing the delimiter uses the normal
/// record path instead. The incomplete tail stays with the refill assembler.
fn GrepInput::count_literal(
  self : GrepInput,
  literal : BytesView,
  invert : Bool,
) -> UInt64 {
  let remaining = self.bytes[self.position:]
  guard remaining.rev_find(self.delimiter) is Some(last) else { return 0UL }
  let complete = remaining[:last + 1]
  let records = @stream.count_byte(complete, self.delimiter[0])
  let mut matched = 0
  if literal.is_empty() {
    matched = records
  } else {
    let mut position = 0
    while position < complete.length() {
      guard complete[position:].find(literal) is Some(relative) else { break }
      let after = position + relative + literal.length()
      let end = after + complete[after:].find(self.delimiter).unwrap()
      matched += 1
      position = end + 1
    }
  }
  self.position += complete.length()
  self.offset += complete.length().to_int64()
  self.number += records.to_int64()
  (if invert { records - matched } else { matched }).to_uint64()
}

///|
fn GrepInput::count_literals(
  self : GrepInput,
  set : @bytere.LiteralSet,
  invert : Bool,
) -> UInt64 {
  let remaining = self.bytes[self.position:]
  guard remaining.rev_find(self.delimiter) is Some(last) else { return 0UL }
  let complete = remaining[:last + 1]
  let records = @stream.count_byte(complete, self.delimiter[0])
  let mut matched = 0
  let mut position = 0
  while position < complete.length() {
    guard set.find_any(complete, start=position) is Some((_, end)) else {
      break
    }
    position = end + complete[end:].find(self.delimiter).unwrap() + 1
    matched += 1
  }
  self.position += complete.length()
  self.offset += complete.length().to_int64()
  self.number += records.to_int64()
  (if invert { records - matched } else { matched }).to_uint64()
}
