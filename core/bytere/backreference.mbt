///|
priv struct RegisterState {
  pc : Int32
  position : Int32
  captures : Array[Int32]
  previous : Array[Int32]
  epsilon : Array[Int32]
} derive(Eq, Hash)

///|
priv enum ReferenceResult {
  Miss
  InvalidSelection
  Matched(Spans)
}

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
  if left >= 0 &&
    right >= left &&
    equal_reference(value, left, right, position, ignore_case) {
    Some(position + right - left)
  } else {
    None
  }
}

///|
fn Pattern::reference_result(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
  restore_registers : Bool,
) -> ReferenceResult {
  let (cache, end, log) = self.candidate_log(value, start, whole, word)
  guard end is Some(end) else { return Miss }
  guard self.sift_candidates(value, start, end, whole, word, cache, log)
    is Some((end, terminal, nodes)) else {
    return Miss
  }
  if !restore_registers {
    return Matched({ start, end, captures: [], })
  }
  match self.select_registers(value, start, end, terminal, nodes) {
    Some(captures) => Matched({ start, end, captures, })
    None => InvalidSelection
  }
}

///|
// Candidate spans determine the endpoint before output registers are restored.
// A failed register selection ends the search, including later starting bytes.
fn Pattern::select_registers(
  self : Pattern,
  value : String,
  start : Int32,
  end : Int32,
  terminal : Int32,
  nodes : Array[Map[Int32, Bool]],
) -> Array[Int32]? {
  let captures = Array::make(self.groups * 2, -1)
  let stack = [
    RegisterState::{
      pc: self.entry,
      position: start,
      captures,
      previous: captures,
      epsilon: [],
    },
  ]
  let seen : Map[RegisterState, Bool] = Map([])
  while stack.pop() is Some(state) {
    let position = state.position
    let pc = state.pc
    if position > end || !nodes[position].contains(pc) || seen.contains(state) {
      continue
    }
    seen[state] = true
    let instruction = self.program[pc]
    let (captures, previous) = match instruction {
      Save(slot, _) =>
        save_tags(state.captures, state.previous, slot, position, false)
      SaveOptional(group, _) =>
        save_tags(state.captures, state.previous, group * 2 + 1, position, true)
      _ => (state.captures, state.previous)
    }
    if (position == end && pc == terminal) || state.epsilon.contains(pc) {
      let mut complete = true
      for group in 0..<self.groups {
        if captures[group * 2] >= 0 && captures[group * 2 + 1] < 0 {
          complete = false
        }
      }
      if complete {
        return Some(captures)
      }
      continue
    }
    let epsilon = state.epsilon.copy()
    epsilon.push(pc)
    let next = match instruction {
      Split(first, second) => {
        let choices = [(second, position)]
        if !epsilon.contains(first) {
          choices.push((first, position))
        }
        choices
      }
      Save(_, next) | SaveOptional(_, next) | Assert(_, next) =>
        [(next, position)]
      Reference(group, next) =>
        match
          reference_end(value, position, captures, group, self.ignore_case) {
          Some(to) =>
            [(if to == position { self.empty_next[pc] } else { next }, to)]
          None => []
        }
      _ =>
        match self.byte_next(value, pc, position) {
          Some(next) => [(next, position + 1)]
          None => []
        }
    }
    for (next, to) in next {
      stack.push({
        pc: next,
        position: to,
        captures,
        previous,
        epsilon: if to == position {
          epsilon
        } else {
          []
        },
      })
    }
  }
  None
}
