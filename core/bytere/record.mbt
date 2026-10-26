///|
/// Reusable boolean search for immutable byte records. The bounded lazy DFA
/// handles assertion-free expressions; other cases retain the span engine's
/// acceptance rules. Construct one matcher per consumer, outside its record loop.
struct RecordMatcher {
  pattern : Pattern
  mut dfa : RecordDfa?
}

///|
pub fn Pattern::record_matcher(self : Pattern) -> RecordMatcher {
  { pattern: self, dfa: RecordDfa::new(self), }
}

///|
pub fn RecordMatcher::matches(
  self : RecordMatcher,
  value : BytesView,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> Bool {
  let required = self.pattern.required_literal
  if required.length() >= 2 && value.find(required) is None {
    return false
  }
  if !whole && !word && self.dfa is Some(dfa) {
    match dfa.matches(value) {
      Some(result) => return result
      None => self.dfa = None
    }
  }
  self.pattern.find_span(text(value), whole~, word~) is Some(_)
}

///|
/// Span extraction always retains leftmost-longest selection and capture-aware
/// backreference handling, independently of the boolean acceleration cache.
pub fn RecordMatcher::find_span(
  self : RecordMatcher,
  value : String,
  start~ : Int32 = 0,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> (Int32, Int32)? {
  self.pattern.find_span(value, start~, whole~, word~)
}

///|
priv struct RecordState {
  nodes : Array[Int32]
  edges : FixedArray[Int32]
}

///|
priv struct RecordDfa {
  pattern : Pattern
  classes : FixedArray[Int32]
  representatives : Array[Int32]
  states : Array[RecordState]
  ids : Map[Array[Int32], Int32]
}

///|
fn Instruction::consumes(self : Instruction, byte : Int32) -> Bool {
  match self {
    Byte(expected, _) => byte == expected
    Any(_) => true
    Class(members, _) => members[byte]
    _ => false
  }
}

///|
fn RecordDfa::new(pattern : Pattern) -> RecordDfa? {
  // Bound both the NFA and cached subsets. Assertions need position/word context,
  // and references need registers; neither is approximated by this byte DFA.
  if pattern.program.length() > 256 ||
    pattern.backreferences ||
    pattern.program.iter().any(instruction => instruction is Assert(_, _)) {
    return None
  }
  let classes = FixedArray::make(256, 0)
  for instruction in pattern.program {
    let partitions : Map[(Int32, Bool), Int32] = Map([])
    for byte in 0..<256 {
      let key = (classes[byte], instruction.consumes(byte))
      let class = match partitions.get(key) {
        Some(class) => class
        None => {
          let class = partitions.length()
          partitions[key] = class
          class
        }
      }
      classes[byte] = class
    }
  }
  let representatives : Array[Int32] = []
  for byte in 0..<256 {
    if classes[byte] == representatives.length() {
      representatives.push(byte)
    }
  }
  let dfa = RecordDfa::{
    pattern,
    classes,
    representatives,
    states: [],
    ids: Map([]),
  }
  let nodes = dfa.closure([pattern.entry])
  dfa.states.push({
    nodes,
    edges: FixedArray::make(representatives.length(), -1),
  })
  dfa.ids[nodes] = 0
  Some(dfa)
}

///|
fn RecordDfa::closure(self : RecordDfa, stack : Array[Int32]) -> Array[Int32] {
  let visited = FixedArray::make(self.pattern.program.length(), false)
  let nodes : Array[Int32] = []
  while stack.pop() is Some(pc) {
    if visited[pc] {
      continue
    }
    visited[pc] = true
    match self.pattern.program[pc] {
      Split(first, second) => {
        stack.push(first)
        stack.push(second)
      }
      Save(_, next) | SaveOptional(_, next) => stack.push(next)
      _ => nodes.push(pc)
    }
  }
  nodes.sort()
  nodes
}

///|
fn RecordDfa::transition(
  self : RecordDfa,
  state : Int32,
  class : Int32,
) -> Int32 {
  let row = self.states[state]
  if row.edges[class] != -1 {
    return row.edges[class]
  }
  let byte = self.representatives[class]
  // In an unanchored boolean search a fresh start is eligible after every byte.
  let seeds = [self.pattern.entry]
  for pc in row.nodes {
    let instruction = self.pattern.program[pc]
    if instruction.consumes(byte) {
      match instruction {
        Byte(_, next) | Class(_, next) | Any(next) => seeds.push(next)
        _ => ()
      }
    }
  }
  let nodes = self.closure(seeds)
  // Accept is instruction zero in every emitted program.
  if nodes[0] == 0 {
    row.edges[class] = -2
    return -2
  }
  if self.ids.get(nodes) is Some(existing) {
    row.edges[class] = existing
    return existing
  }
  if self.states.length() >= 256 {
    return -3
  }
  let next = self.states.length()
  self.ids[nodes] = next
  self.states.push({
    nodes,
    edges: FixedArray::make(self.representatives.length(), -1),
  })
  row.edges[class] = next
  next
}

///|
fn RecordDfa::matches(self : RecordDfa, value : BytesView) -> Bool? {
  if self.states[0].nodes[0] == 0 {
    return Some(true)
  }
  let mut state = 0
  for byte in value {
    let class = self.classes[byte.to_int()]
    let edge = self.states[state].edges[class]
    let next = if edge == -1 { self.transition(state, class) } else { edge }
    if next == -2 {
      return Some(true)
    }
    if next == -3 {
      return None
    }
    state = next
  }
  Some(false)
}

///|
/// A conservative mandatory literal: concatenation requires every child,
/// positive repetition requires its body, and alternatives must agree.
/// Optional/case-folded classes and backreferences contribute no literal.
fn Tree::required_literal(self : Tree) -> String {
  match self {
    Literal(code) => code.unsafe_to_char().to_string()
    Capture(_, inner) => inner.required_literal()
    Repeat(inner, minimum, _) =>
      if minimum > 0 {
        inner.required_literal()
      } else {
        ""
      }
    Sequence(parts) => {
      let mut best = ""
      let mut run = StringBuilder()
      for part in parts {
        if part.is_literal() {
          ignore(part.literal_prefix(run))
        } else {
          let literal = run.to_string()
          if literal.length() > best.length() {
            best = literal
          }
          let required = part.required_literal()
          if required.length() > best.length() {
            best = required
          }
          run = StringBuilder()
        }
      }
      let literal = run.to_string()
      if literal.length() > best.length() {
        literal
      } else {
        best
      }
    }
    Choice(branches) => {
      let required = branches[0].required_literal()
      if branches.iter().all(branch => branch.required_literal() == required) {
        required
      } else {
        ""
      }
    }
    _ => ""
  }
}
