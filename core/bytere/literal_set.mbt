///|
/// A bounded literal set using two-byte shifts or a byte-class Aho-Corasick table.
struct LiteralSet {
  classes : FixedArray[Int32]
  shift : LiteralShift?
  mut automaton : LiteralAutomaton?
  mut automaton_attempted : Bool
}

///|
/// Compile up to 4096 literal bytes. Patterns of at least three bytes use a
/// two-byte shift table; dense failed verification can lazily select an automaton
/// with at most 1024 states. Short patterns start with that automaton. A failed
/// lazy construction preserves the shift plan and is never retried for this set.
/// Empty patterns or sets exceeding their initial budgets return None.
///
/// ```mbt check
/// test {
///   let set = @bytere.LiteralSet::new([b"ab", b"aba", b"b"]).unwrap()
///   assert_eq(set.find_span(b"zaba"), Some((1, 4)))
///   assert_eq(set.find_span(b"zaba", start=2), Some((2, 3)))
///   assert_true(set.matches(b"zaba"))
///   assert_true(!set.contains_byte(b'\n'))
/// }
/// ```
pub fn LiteralSet::new(patterns : Array[Bytes]) -> LiteralSet? {
  if patterns.is_empty() || patterns.iter().any(pattern => pattern.is_empty()) {
    return None
  }
  let classes = FixedArray::make(256, 0)
  let mut width = 1
  let mut total = 0
  for pattern in patterns {
    if pattern.length() > 4096 - total {
      return None
    }
    total += pattern.length()
    for byte in pattern {
      if classes[byte.to_int()] == 0 {
        classes[byte.to_int()] = width
        width += 1
      }
    }
  }
  if LiteralShift::new(patterns) is Some(shift) {
    return Some({
      classes,
      shift: Some(shift),
      automaton: None,
      automaton_attempted: false,
    })
  }
  guard LiteralAutomaton::new(patterns, classes) is Some(automaton) else {
    return None
  }
  Some({
    classes,
    shift: None,
    automaton: Some(automaton),
    automaton_attempted: true,
  })
}

///|
/// Whether any literal contains byte; useful when a block consumer must reject
/// candidate spans that could cross its record delimiter.
pub fn LiteralSet::contains_byte(self : LiteralSet, byte : Byte) -> Bool {
  self.classes[byte.to_int()] != 0
}

///|
/// Return the earliest start and longest match at that start, relative to value.
pub fn LiteralSet::find_span(
  self : LiteralSet,
  value : BytesView,
  start~ : Int32 = 0,
) -> (Int32, Int32)? {
  self.search(value, start, false)
}

///|
/// Whether value contains any compiled literal.
pub fn LiteralSet::matches(self : LiteralSet, value : BytesView) -> Bool {
  self.search(value, 0, true) is Some(_)
}

///|
/// Return a verified occurrence without resolving longest ties. The automaton
/// stops at its first accepting endpoint; the shift plan stops at its first
/// matching start. For delimiter-free literals, neither skips an earlier
/// matching record. Use find_span when leftmost-longest selection is required.
pub fn LiteralSet::find_any(
  self : LiteralSet,
  value : BytesView,
  start~ : Int32 = 0,
) -> (Int32, Int32)? {
  self.search(value, start, true)
}

///|
fn LiteralSet::search(
  self : LiteralSet,
  value : BytesView,
  start : Int32,
  first_only : Bool,
) -> (Int32, Int32)? {
  if start < 0 || start >= value.length() {
    return None
  }
  if self.shift is Some(shift) {
    // Reconsider each input even when the automaton is cached: a later sparse
    // record can still benefit from shifts. Only construction is memoized.
    let found = shift.find(
      value,
      start,
      first_only,
      allow_switch=!self.automaton_attempted || self.automaton is Some(_),
    )
    match found {
      Some((-1, next_start)) => {
        if !self.automaton_attempted {
          self.automaton_attempted = true
          self.automaton = LiteralAutomaton::new(shift.patterns, self.classes)
        }
        if self.automaton is Some(automaton) {
          return automaton.search(value, next_start, first_only)
        }
        // Budget exhaustion resumes after fully rejected starts. It neither
        // loses a match nor repeats construction on this or subsequent inputs.
        return shift.find(value, next_start, first_only, allow_switch=false)
      }
      _ => return found
    }
  }
  match self.automaton {
    Some(automaton) => automaton.search(value, start, first_only)
    None => None
  }
}
