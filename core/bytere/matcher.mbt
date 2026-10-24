///|
priv struct Thread {
  pc : Int32
  start : Int32
  captures : Array[Int32]
  previous : Array[Int32]
}

///|
priv struct State {
  pc : Int32
  position : Int32
  captures : Array[Int32]
  previous : Array[Int32]
} derive(Eq, Hash)

///|
priv struct Tags {
  pc : Int32
  captures : Array[Int32]
  previous : Array[Int32]
} derive(Eq, Hash)

///|
priv struct Spans {
  start : Int32
  end : Int32
  captures : Array[Int32]
}

///|
fn word_byte(value : String, index : Int32) -> Bool {
  if index < 0 || index >= value.length() {
    return false
  }
  let c = value[index].to_int()
  c == 95 ||
  (c >= 48 && c <= 57) ||
  (c >= 65 && c <= 90) ||
  (c >= 97 && c <= 122)
}

///|
fn Assertion::holds(self : Assertion, value : String, position : Int32) -> Bool {
  let left = word_byte(value, position - 1)
  let right = word_byte(value, position)
  match self {
    Begin => position == 0
    End => position == value.length()
    WordBegin => !left && right
    WordEnd => left && !right
    WordBoundary => left != right
    NotWordBoundary => left == right
  }
}

///|
fn accepted(
  value : String,
  start : Int32,
  end : Int32,
  whole : Bool,
  word : Bool,
) -> Bool {
  (!whole || (start == 0 && end == value.length())) &&
  (!word || (!word_byte(value, start - 1) && !word_byte(value, end)))
}

///|
fn Pattern::prefix_at(self : Pattern, value : String, position : Int32) -> Bool {
  position + self.prefix.length() <= value.length() &&
  value[position:position + self.prefix.length()] == self.prefix
}

///|
fn better(best : Spans?, start : Int32, end : Int32) -> Bool {
  match best {
    None => true
    Some(hit) => start < hit.start || (start == hit.start && end > hit.end)
  }
}

///|
fn Pattern::search(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
  need_captures : Bool,
) -> Spans? {
  if start < 0 || start > value.length() || (whole && start != 0) {
    return None
  }
  if self.literal is Some(literal) {
    let mut position = start
    while position <= value.length() {
      guard value[position:].find(literal) is Some(offset) else { return None }
      let left = position + offset
      let end = left + literal.length()
      if accepted(value, left, end, whole, word) {
        return Some({ start: left, end, captures: [], })
      }
      position = left + 1
      if whole {
        return None
      }
    }
    return None
  }
  if self.backreferences {
    for left in start..<=value.length() {
      if self.prefix_at(value, left) {
        let hit = if need_captures {
          self.at(value, left, whole, word)
        } else {
          self.backreference_at(value, left, whole, word, false)
        }
        if hit is Some(hit) {
          return Some(hit)
        }
      }
      if whole {
        break
      }
    }
    return None
  }
  self.ordinary(value, start, whole, word, need_captures)
}

///|
/// Ordered Thompson threads retain every distinct set of current and previous
/// capture tags when requested. Equal (instruction, both tag sets) at a byte
/// position have identical futures; the earlier eligible start dominates,
/// then the first ordered path wins an equal-length tie.
/// Without backreferences, tags cannot affect acceptance, so span-only searches
/// erase Save operations and visit O(program size) states per byte.
/// Captures can create many distinct tag states; they are never merged merely
/// because their program counters agree.
fn Pattern::ordinary(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
  need_captures : Bool,
) -> Spans? {
  let mut threads : Array[Thread] = []
  let mut best : Spans? = None
  let mut position = start
  while position <= value.length() {
    // Every possible match starts with this literal prefix. With no live
    // threads there is no intermediate position whose state must be kept.
    if threads.is_empty() && best is None && !self.prefix.is_empty() {
      guard value[position:].find(self.prefix) is Some(offset) else { break }
      position += offset
    }
    if best is None &&
      (!whole || position == 0) &&
      (!word || !word_byte(value, position - 1)) &&
      self.prefix_at(value, position) {
      let captures = Array::make(
        if need_captures {
          self.groups * 2
        } else {
          0
        },
        -1,
      )
      threads.push({
        pc: self.entry,
        start: position,
        captures,
        previous: captures,
      })
    }
    let stack : Array[Thread] = []
    for i = threads.length() - 1; i >= 0; i = i - 1 {
      stack.push(threads[i])
    }
    let seen : Map[Tags, Bool] = Map([])
    let next_threads : Array[Thread] = []
    while stack.pop() is Some(thread) {
      if best is Some(hit) && thread.start > hit.start {
        continue
      }
      let key = Tags::{
        pc: thread.pc,
        captures: thread.captures,
        previous: thread.previous,
      }
      if seen.contains(key) {
        continue
      }
      seen[key] = true
      match self.program[thread.pc] {
        Accept =>
          if accepted(value, thread.start, position, whole, word) &&
            better(best, thread.start, position) {
            best = Some({
              start: thread.start,
              end: position,
              captures: thread.captures,
            })
          }
        Split(first, second) => {
          stack.push({ ..thread, pc: second, })
          stack.push({ ..thread, pc: first, })
        }
        Save(slot, next) =>
          if need_captures {
            let (captures, previous) = save_tags(
              thread.captures,
              thread.previous,
              slot,
              position,
              false,
            )
            stack.push({ ..thread, pc: next, captures, previous, })
          } else {
            stack.push({ ..thread, pc: next, })
          }
        SaveOptional(group, next) =>
          if need_captures {
            let (captures, previous) = save_tags(
              thread.captures,
              thread.previous,
              group * 2 + 1,
              position,
              true,
            )
            stack.push({ ..thread, pc: next, captures, previous, })
          } else {
            stack.push({ ..thread, pc: next, })
          }
        Assert(assertion, next) =>
          if assertion.holds(value, position) {
            stack.push({ ..thread, pc: next, })
          }
        Byte(c, next) =>
          if position < value.length() && value[position].to_int() == c {
            next_threads.push({ ..thread, pc: next, })
          }
        Any(next) =>
          if position < value.length() {
            next_threads.push({ ..thread, pc: next, })
          }
        Class(members, next) =>
          if position < value.length() &&
            value[position].to_int() < 256 &&
            members[value[position].to_int()] {
            next_threads.push({ ..thread, pc: next, })
          }
        Reference(_, _) => abort("backreference in ordinary regex program")
      }
    }
    threads = next_threads
    if best is Some(_) && threads.is_empty() {
      break
    }
    position += 1
  }
  best
}

///|
/// Backreferences consume captured byte spans directly. The explicit DFS stack
/// preserves alternative/greedy order, with no recursion or matching-step cap.
/// Only exact states are memoized, including all capture boundaries. Ambiguous
/// backreference expressions can still require exponential time and memory.
fn Pattern::at(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
) -> Spans? {
  if self.backreferences {
    return self.backreference_at(value, start, whole, word, true)
  }
  let captures = Array::make(self.groups * 2, -1)
  let stack = [
    State::{ pc: self.entry, position: start, captures, previous: captures, },
  ]
  let seen : Map[State, Bool] = Map([])
  let mut best : Spans? = None
  while stack.pop() is Some(state) {
    if seen.contains(state) {
      continue
    }
    seen[state] = true
    let position = state.position
    match self.program[state.pc] {
      Accept =>
        if accepted(value, start, position, whole, word) &&
          better(best, start, position) {
          best = Some({ start, end: position, captures: state.captures, })
        }
      Split(first, second) => {
        stack.push({ ..state, pc: second, })
        stack.push({ ..state, pc: first, })
      }
      Save(slot, next) => {
        let (captures, previous) = save_tags(
          state.captures,
          state.previous,
          slot,
          position,
          false,
        )
        stack.push({ ..state, pc: next, captures, previous, })
      }
      SaveOptional(group, next) => {
        let (captures, previous) = save_tags(
          state.captures,
          state.previous,
          group * 2 + 1,
          position,
          true,
        )
        stack.push({ ..state, pc: next, captures, previous, })
      }
      Assert(assertion, next) =>
        if assertion.holds(value, position) {
          stack.push({ ..state, pc: next, })
        }
      Byte(c, next) =>
        if position < value.length() && value[position].to_int() == c {
          stack.push({ ..state, pc: next, position: position + 1, })
        }
      Any(next) =>
        if position < value.length() {
          stack.push({ ..state, pc: next, position: position + 1, })
        }
      Class(members, next) =>
        if position < value.length() &&
          value[position].to_int() < 256 &&
          members[value[position].to_int()] {
          stack.push({ ..state, pc: next, position: position + 1, })
        }
      Reference(group, next) => {
        let left = state.captures[group * 2]
        let right = state.captures[group * 2 + 1]
        if left >= 0 &&
          right >= left &&
          position + right - left <= value.length() &&
          value[left:right] == value[position:position + right - left] {
          stack.push({ ..state, pc: next, position: position + right - left, })
        }
      }
    }
  }
  best
}

///|
/// GNU regexec.c's update_regs retains the previous complete register set
/// when an optional repeated group finishes empty after an earlier match.
/// Both register sets are part of state identity: restoring the outer group
/// must also undo changes to its nested groups.
fn save_tags(
  captures : Array[Int32],
  previous : Array[Int32],
  slot : Int32,
  position : Int32,
  optional : Bool,
) -> (Array[Int32], Array[Int32]) {
  if slot % 2 == 1 &&
    optional &&
    captures[slot - 1] == position &&
    previous[slot - 1] >= 0 {
    return (previous, previous)
  }
  let updated = captures.copy()
  updated[slot] = position
  if slot % 2 == 0 {
    updated[slot + 1] = -1
  }
  let snapshot = if slot % 2 == 1 && updated[slot - 1] < position {
    updated
  } else {
    previous
  }
  (updated, snapshot)
}
