///|
/// Position-independent epsilon closures erase Save/Split dispatch from the hot
/// span loop. Nodes within one start need no capture ordering; earlier starts
/// still enter each position first and dominate equal program counters.
priv struct SpanPlan {
  closures : Array[Array[Int32]]
  pcs : Array[Int32]
  starts : Array[Int32]
  next_pcs : Array[Int32]
  next_starts : Array[Int32]
  seen : FixedArray[Int32]
}

///|
fn SpanPlan::new(pattern : Pattern) -> SpanPlan? {
  if pattern.program.length() > 256 ||
    pattern.backreferences ||
    pattern.program.iter().any(instruction => instruction is Assert(_, _)) {
    return None
  }
  let closures = Array::makei(pattern.program.length(), entry => {
    let stack = [entry]
    let visited = FixedArray::make(pattern.program.length(), false)
    let nodes : Array[Int32] = []
    while stack.pop() is Some(pc) {
      if visited[pc] {
        continue
      }
      visited[pc] = true
      match pattern.program[pc] {
        Split(first, second) => {
          stack.push(first)
          stack.push(second)
        }
        Save(_, next) | SaveOptional(_, next) => stack.push(next)
        _ => nodes.push(pc)
      }
    }
    nodes
  })
  Some({
    closures,
    pcs: [],
    starts: [],
    next_pcs: [],
    next_starts: [],
    seen: FixedArray::make(pattern.program.length(), -1),
  })
}

///|
#inline
fn SpanPlan::insert(
  self : SpanPlan,
  entry : Int32,
  left : Int32,
  position : Int32,
  pcs : Array[Int32],
  starts : Array[Int32],
) -> Unit {
  for pc in self.closures[entry] {
    if self.seen[pc] != position {
      self.seen[pc] = position
      pcs.push(pc)
      starts.push(left)
    }
  }
}

///|
fn SpanPlan::find(
  self : SpanPlan,
  pattern : Pattern,
  value : StringView,
  start : Int32,
  whole : Bool,
  word : Bool,
) -> (Int32, Int32)? {
  if start < 0 || start > value.length() || (whole && start != 0) {
    return None
  }
  let mut pcs = self.pcs
  let mut starts = self.starts
  let mut next_pcs = self.next_pcs
  let mut next_starts = self.next_starts
  pcs.clear()
  starts.clear()
  next_pcs.clear()
  next_starts.clear()
  for index in 0..<self.seen.length() {
    self.seen[index] = -1
  }
  let mut position = start
  let mut best_start = -1
  let mut best_end = -1
  while position <= value.length() {
    if pcs.is_empty() && best_start < 0 && !pattern.prefix.is_empty() {
      guard value[position:].find(pattern.prefix) is Some(offset) else { break }
      position += offset
    }
    if best_start < 0 &&
      (!whole || position == 0) &&
      (!word || !word_byte(value, position - 1)) &&
      pattern.prefix_at(value, position) {
      self.insert(pattern.entry, position, position, pcs, starts)
    }
    for index in 0..<pcs.length() {
      let left = starts[index]
      if best_start >= 0 && left > best_start {
        continue
      }
      match pattern.program[pcs[index]] {
        Accept =>
          if accepted(value, left, position, whole, word) &&
            (
              best_start < 0 ||
              left < best_start ||
              (left == best_start && position > best_end)
            ) {
            best_start = left
            best_end = position
          }
        Byte(byte, next) =>
          if position < value.length() && value[position].to_int() == byte {
            self.insert(next, left, position + 1, next_pcs, next_starts)
          }
        Class(members, next) =>
          if position < value.length() &&
            value[position].to_int() < 256 &&
            members[value[position].to_int()] {
            self.insert(next, left, position + 1, next_pcs, next_starts)
          }
        Any(next) =>
          if position < value.length() {
            self.insert(next, left, position + 1, next_pcs, next_starts)
          }
        _ => abort("non-consuming instruction in span closure")
      }
    }
    let old_pcs = pcs
    let old_starts = starts
    pcs = next_pcs
    starts = next_starts
    next_pcs = old_pcs
    next_starts = old_starts
    next_pcs.clear()
    next_starts.clear()
    if best_start >= 0 && pcs.is_empty() {
      break
    }
    position += 1
  }
  if best_start < 0 {
    None
  } else {
    Some((best_start, best_end))
  }
}
