///|
/// Count matching complete records without rebuilding the boolean dispatch for
/// each record, returning `(matching_records, complete_records)`. An incomplete
/// tail is excluded. Unsupported expressions and exhausted DFAs return None;
/// callers must use ordinary matching for the entire block in that case.
pub fn RecordMatcher::count_records(
  self : RecordMatcher,
  data : BytesView,
  separator : Byte,
) -> (Int32, Int32)? {
  if self.dfa is Uninitialized {
    self.dfa = engine_cache(RecordDfa::new(self.pattern))
  }
  guard self.dfa is Ready(dfa) else { return None }
  let required = self.pattern.required_literal
  let delimiter = Bytes::from_array([separator])
  let mut position = 0
  let mut records = 0
  let mut matched = 0
  while data[position:].find(delimiter) is Some(relative) {
    let end = position + relative
    let record = data[position:end]
    let selected = if required.length() >= 2 && record.find(required) is None {
      Some(false)
    } else if required.is_empty() && relative >= 256 {
      dfa.matches_accelerated(record)
    } else {
      dfa.matches(record)
    }
    guard selected is Some(selected) else {
      self.dfa = Disabled
      return None
    }
    if selected {
      matched += 1
    }
    records += 1
    position = end + 1
  }
  Some((matched, records))
}
