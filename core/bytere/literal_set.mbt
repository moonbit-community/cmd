///|
/// A bounded literal set using two-byte shifts or a byte-class Aho-Corasick table.
struct LiteralSet {
  classes : FixedArray[Int32]
  transitions : FixedArray[Int32]
  lengths : FixedArray[Int32]
  maximum : Int32
  first : Bytes?
  shift : LiteralShift?
}

///|
/// Compile up to 4096 literal bytes. Patterns of at least three bytes use a
/// two-byte shift table; shorter patterns use at most 1024 trie states.
/// Empty patterns or sets exceeding these budgets return None.
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
  let mut maximum = 0
  let mut first = Some(patterns[0][0])
  for pattern in patterns {
    if pattern.length() > 4096 - total {
      return None
    }
    total += pattern.length()
    maximum = maximum.max(pattern.length())
    if first != Some(pattern[0]) {
      first = None
    }
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
      transitions: [],
      lengths: [],
      maximum,
      first: None,
      shift: Some(shift),
    })
  }
  let children : Array[Map[Int32, Int32]] = [Map([])]
  let terminal = [0]
  for pattern in patterns {
    let mut state = 0
    for byte in pattern {
      let class = classes[byte.to_int()]
      state = match children[state].get(class) {
        Some(next) => next
        None => {
          if children.length() >= 1024 {
            return None
          }
          let next = children.length()
          children[state][class] = next
          children.push(Map([]))
          terminal.push(0)
          next
        }
      }
    }
    terminal[state] = terminal[state].max(pattern.length())
  }
  let count = children.length()
  let transitions = FixedArray::make(count * width, 0)
  let failure = FixedArray::make(count, 0)
  let queue : Array[Int32] = []
  for (class, child) in children[0] {
    transitions[class] = child
    queue.push(child)
  }
  let mut position = 0
  while position < queue.length() {
    let state = queue[position]
    position += 1
    terminal[state] = terminal[state].max(terminal[failure[state]])
    for class in 0..<width {
      let fallback = transitions[failure[state] * width + class]
      transitions[state * width + class] = match children[state].get(class) {
        Some(child) => {
          failure[child] = fallback
          queue.push(child)
          child
        }
        None => fallback
      }
    }
  }
  let lengths = FixedArray::make(count * width, 0)
  for state in 0..<count {
    lengths[state * width] = terminal[state]
  }
  for slot in 0..<transitions.length() {
    transitions[slot] *= width
  }
  Some({
    classes,
    transitions,
    lengths,
    maximum,
    first: first.map(byte => Bytes::from_array([byte])),
    shift: None,
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
    return shift.find(value, start, first_only)
  }
  let mut state = 0
  let mut position = start
  let mut left = -1
  let mut right = -1
  while position < value.length() {
    if state == 0 && self.first is Some(byte) && value.length() - position >= 32 {
      guard value[position:].find(byte) is Some(offset) else { break }
      position += offset
    }
    state = self.transitions[state + self.classes[value[position].to_int()]]
    position += 1
    let length = self.lengths[state]
    if length > 0 {
      let begin = position - length
      if first_only {
        return Some((begin, position))
      }
      if left < 0 || begin < left || (begin == left && position > right) {
        left = begin
        right = position
      }
    }
    if left >= 0 && position - left >= self.maximum {
      break
    }
  }
  if left < 0 {
    None
  } else {
    Some((left, right))
  }
}
