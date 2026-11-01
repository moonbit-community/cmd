///|
// Strategy: sed-byte-prefilter

///|
priv struct PreparedPattern {
  pattern : @bytere.Pattern
  required : Bytes
}

///|
fn PreparedPattern::new(pattern : @bytere.Pattern) -> PreparedPattern {
  { pattern, required: pattern.record_matcher().required_literal(), }
}

///|
// Rejection never establishes a match. Text-only spaces and uncertain literals
// retain the existing capture-aware engine, including multiline semantics.
fn PreparedPattern::rejects(self : PreparedPattern, space : Space) -> Bool {
  if self.required.length() < 2 {
    return false
  }
  match space.data {
    Some(bytes) => bytes.find(self.required) is None
    None => false
  }
}

///|
fn PreparedPattern::matches(self : PreparedPattern, space : Space) -> Bool {
  !self.rejects(space) && self.pattern.is_match(space.text())
}
