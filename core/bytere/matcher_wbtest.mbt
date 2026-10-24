///|
priv struct State {
  pc : Int32
  position : Int32
  captures : Array[Int32]
  previous : Array[Int32]
} derive(Eq, Hash)

///|
// Independent tagged DFS used only to check the ordinary Thompson matcher.
fn Pattern::at(
  self : Pattern,
  value : String,
  start : Int32,
  whole : Bool,
  word : Bool,
) -> Spans? {
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
test "ordered ordinary threads agree with explicit tagged DFS" {
  let inputs = [
    "", "a", "b", "aa", "ab", "ba", "bb", "aaa", "aab", "aba", "abb", "baa", "bab",
    "bba", "bbb", "aaaa", "abab",
  ]
  for
    source in [
      "a*", "a|aa", "(a|aa)(a*)", "(a*)*", "((a*)*)*", "(a|(b))*", "(a?)*", "(a?)(a*)",
      "(a|())*", "((a|b)*)", "(a|ab){0,2}", "(a*){2,}", "((a?)*)b?", "(a|b)*a(a|b)*",
    ] {
    let pattern = compile(source, extended=true)
    for input in inputs {
      let ordinary = pattern.ordinary(input, 0, false, false, true)
      let spans = pattern.ordinary(input, 0, false, false, false)
      assert_eq(
        spans.map(hit => (hit.start, hit.end)),
        ordinary.map(hit => (hit.start, hit.end)),
        msg=source + " spans on " + input,
      )
      let mut explicit : Spans? = None
      for start in 0..<=input.length() {
        if pattern.at(input, start, false, false) is Some(hit) {
          explicit = Some(hit)
          break
        }
      }
      assert_eq(
        ordinary.map(hit => (hit.start, hit.end, hit.captures)),
        explicit.map(hit => (hit.start, hit.end, hit.captures)),
        msg=source + " on " + input,
      )
    }
  }
}
