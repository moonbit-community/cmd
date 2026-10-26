///|
/// Span searches have no observable capture registers. Store only program
/// counters and start offsets, and reuse the three worklists across bytes.
/// Earlier starts are visited first; a visited instruction has the same future
/// at this position, so later starts cannot improve the leftmost-longest result.
fn Pattern::span_ordinary(
  self : Pattern,
  value : StringView,
  start : Int32,
  whole : Bool,
  word : Bool,
  start_only : Bool,
) -> Spans? {
  let mut pcs : Array[Int32] = []
  let mut starts : Array[Int32] = []
  let mut next_pcs : Array[Int32] = []
  let mut next_starts : Array[Int32] = []
  let stack_pcs : Array[Int32] = []
  let stack_starts : Array[Int32] = []
  let seen = FixedArray::make(self.program.length(), -1)
  let mut best_start = -1
  let mut best_end = -1
  let mut position = start
  while position <= value.length() {
    if !start_only &&
      pcs.is_empty() &&
      best_start < 0 &&
      !self.prefix.is_empty() {
      guard value[position:].find(self.prefix) is Some(offset) else { break }
      position += offset
    }
    if best_start < 0 &&
      (!start_only || position == start) &&
      (!whole || position == 0) &&
      (!word || !word_byte(value, position - 1)) &&
      self.prefix_at(value, position) {
      pcs.push(self.entry)
      starts.push(position)
    }
    for index = pcs.length() - 1; index >= 0; index = index - 1 {
      stack_pcs.push(pcs[index])
      stack_starts.push(starts[index])
    }
    while stack_pcs.pop() is Some(pc) {
      let left = stack_starts.pop().unwrap()
      if (best_start >= 0 && left > best_start) || seen[pc] == position {
        continue
      }
      seen[pc] = position
      match self.program[pc] {
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
        Split(first, second) => {
          stack_pcs.push(second)
          stack_starts.push(left)
          stack_pcs.push(first)
          stack_starts.push(left)
        }
        Save(_, next) | SaveOptional(_, next) => {
          stack_pcs.push(next)
          stack_starts.push(left)
        }
        Assert(assertion, next) =>
          if assertion.holds(value, position) {
            stack_pcs.push(next)
            stack_starts.push(left)
          }
        Byte(c, next) =>
          if position < value.length() && value[position].to_int() == c {
            next_pcs.push(next)
            next_starts.push(left)
          }
        Any(next) =>
          if position < value.length() {
            next_pcs.push(next)
            next_starts.push(left)
          }
        Class(members, next) =>
          if position < value.length() &&
            value[position].to_int() < 256 &&
            members[value[position].to_int()] {
            next_pcs.push(next)
            next_starts.push(left)
          }
        Reference(_, _) => abort("backreference in span-only regex program")
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
    if (best_start >= 0 || start_only) && pcs.is_empty() {
      break
    }
    position += 1
  }
  if best_start < 0 {
    None
  } else {
    Some({ start: best_start, end: best_end, captures: [], })
  }
}
