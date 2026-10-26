///|
priv struct LiteralAutomaton {
  classes : FixedArray[Int32]
  transitions : FixedArray[Int32]
  lengths : FixedArray[Int32]
  maximum : Int32
  first : Bytes?
}

///|
fn LiteralAutomaton::new(
  patterns : Array[Bytes],
  classes : FixedArray[Int32],
) -> LiteralAutomaton? {
  let mut width = 1
  for class in classes {
    width = width.max(class + 1)
  }
  let mut maximum = 0
  let mut first = Some(patterns[0][0])
  let children : Array[Map[Int32, Int32]] = [Map([])]
  let terminal = [0]
  for pattern in patterns {
    maximum = maximum.max(pattern.length())
    if first != Some(pattern[0]) {
      first = None
    }
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
  })
}

///|
fn LiteralAutomaton::search(
  self : LiteralAutomaton,
  value : BytesView,
  start : Int32,
  first_only : Bool,
) -> (Int32, Int32)? {
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
