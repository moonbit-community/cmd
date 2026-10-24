///|
priv struct RawState {
  pc : Int32
  position : Int32
  captures : Array[Int32]
} derive(Eq, Hash)

///|
priv struct RegisterState {
  raw : RawState
  captures : Array[Int32]
  previous : Array[Int32]
  epsilon : Array[Int32]
} derive(Eq, Hash)

///|
fn reference_end(
  value : String,
  position : Int32,
  captures : Array[Int32],
  group : Int32,
  ignore_case : Bool,
) -> Int32? {
  let left = captures[group * 2]
  let right = captures[group * 2 + 1]
  if left >= 0 && right >= left && position + right - left <= value.length() {
    if ignore_case {
      for offset in 0..<(right - left) {
        if ascii_fold(value[left + offset].to_int()) !=
          ascii_fold(value[position + offset].to_int()) {
          return None
        }
      }
    } else if value[left:right] != value[position:position + right - left] {
      return None
    }
    Some(position + right - left)
  } else {
    None
  }
}

///|
/// Optional-group output restoration is not a language transition. A later
/// backreference must first see the actual current capture, including empty
/// final iterations. These raw states retain every distinct capture history.
fn Pattern::raw_next(
  self : Pattern,
  value : String,
  state : RawState,
) -> Array[RawState] {
  let position = state.position
  match self.program[state.pc] {
    Accept => []
    Split(first, second) => [{ ..state, pc: first, }, { ..state, pc: second, }]
    Save(slot, next) => {
      let captures = state.captures.copy()
      captures[slot] = position
      if slot % 2 == 0 {
        captures[slot + 1] = -1
      }
      [{ ..state, pc: next, captures, }]
    }
    SaveOptional(group, next) => {
      let captures = state.captures.copy()
      captures[group * 2 + 1] = position
      [{ ..state, pc: next, captures, }]
    }
    Assert(assertion, next) =>
      if assertion.holds(value, position) {
        [{ ..state, pc: next, }]
      } else {
        []
      }
    Byte(c, next) =>
      if position < value.length() && value[position].to_int() == c {
        [{ ..state, pc: next, position: position + 1, }]
      } else {
        []
      }
    Any(next) =>
      if position < value.length() {
        [{ ..state, pc: next, position: position + 1, }]
      } else {
        []
      }
    Class(members, next) =>
      if position < value.length() &&
        value[position].to_int() < 256 &&
        members[value[position].to_int()] {
        [{ ..state, pc: next, position: position + 1, }]
      } else {
        []
      }
    Reference(group, next) =>
      match
        reference_end(value, position, state.captures, group, self.ignore_case) {
        Some(end) => [{ ..state, pc: next, position: end, }]
        None => []
      }
  }
}

///|
/// Language matching and output-register selection are separate. Every graph
/// node includes all live capture spans; reverse pruning keeps full-state
/// edges, never a union of instruction/position coordinates. Ambiguous inputs
/// can still require exponential state and edge storage; there is no step cap.
fn Pattern::backreference_at(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
  need_captures : Bool,
) -> Spans? {
  let initial = RawState::{
    pc: self.entry,
    position: start,
    captures: Array::make(self.groups * 2, -1),
  }
  let stack = [initial]
  let seen : Map[RawState, Bool] = Map([])
  let edges : Map[RawState, Array[RawState]] = Map([])
  let parents : Map[RawState, Array[RawState]] = Map([])
  let terminals : Array[RawState] = []
  let mut best : Spans? = None
  while stack.pop() is Some(state) {
    if seen.contains(state) {
      continue
    }
    seen[state] = true
    if self.program[state.pc] is Accept &&
      accepted(value, start, state.position, whole, word) {
      terminals.push(state)
      if better(best, start, state.position) {
        best = Some({ start, end: state.position, captures: state.captures, })
      }
    }
    let next = self.raw_next(value, state)
    if need_captures {
      edges[state] = next
      for child in next {
        if parents.get(child) is Some(previous) {
          previous.push(state)
        } else {
          parents[child] = [state]
        }
      }
    }
    for i = next.length() - 1; i >= 0; i = i - 1 {
      stack.push(next[i])
    }
  }
  guard best is Some(hit) else { return None }
  if !need_captures {
    return Some(hit)
  }
  let pending : Array[RawState] = []
  for terminal in terminals {
    if terminal.position == hit.end {
      pending.push(terminal)
    }
  }
  let valid : Map[RawState, Bool] = Map([])
  while pending.pop() is Some(state) {
    if valid.contains(state) {
      continue
    }
    valid[state] = true
    if parents.get(state) is Some(previous) {
      pending.append(previous)
    }
  }
  let captures = self
    .select_registers(initial, hit.end, edges, valid)
    .unwrap_or(hit.captures)
  Some({ ..hit, captures, })
}

///|
/// Reconstruct over coherent surviving raw edges. GNU output registers restore
/// earlier captures independently of the raw tags used to match a reference.
/// At the winning endpoint, a zero-progress cycle with complete registers ends
/// selection after its register update, as in GNU regexec.c's set_regs. The raw
/// node still has a proven zero-byte continuation to an accepting endpoint.
/// If selection fails, retain the raw winning path's captures.
fn Pattern::select_registers(
  self : Pattern,
  initial : RawState,
  end : Int32,
  edges : Map[RawState, Array[RawState]],
  valid : Map[RawState, Bool],
) -> Array[Int32]? {
  let stack = [
    RegisterState::{
      raw: initial,
      captures: initial.captures,
      previous: initial.captures,
      epsilon: [],
    },
  ]
  let seen : Map[RegisterState, Bool] = Map([])
  while stack.pop() is Some(state) {
    if !valid.contains(state.raw) || seen.contains(state) {
      continue
    }
    seen[state] = true
    let pc = state.raw.pc
    let position = state.raw.position
    let instruction = self.program[pc]
    let (captures, previous) = match instruction {
      Save(slot, _) =>
        save_tags(state.captures, state.previous, slot, position, false)
      SaveOptional(group, _) =>
        save_tags(state.captures, state.previous, group * 2 + 1, position, true)
      _ => (state.captures, state.previous)
    }
    if instruction is Accept && position == end {
      return Some(captures)
    }
    if state.epsilon.contains(pc) {
      if position == end {
        let mut complete = true
        for group in 0..<self.groups {
          if captures[group * 2] >= 0 && captures[group * 2 + 1] == -1 {
            complete = false
          }
        }
        if complete {
          return Some(captures)
        }
      }
      continue
    }
    let epsilon = state.epsilon.copy()
    epsilon.push(pc)
    guard edges.get(state.raw) is Some(next) else { continue }
    for i = next.length() - 1; i >= 0; i = i - 1 {
      let child = next[i]
      if !valid.contains(child) {
        continue
      }
      if instruction is Split(first, _) &&
        child.pc == first &&
        epsilon.contains(first) {
        continue
      }
      stack.push({
        raw: child,
        captures,
        previous,
        epsilon: if child.position == position {
          epsilon
        } else {
          []
        },
      })
    }
  }
  None
}
