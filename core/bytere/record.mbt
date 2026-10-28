///|
/// Reusable boolean search for immutable byte records. The bounded lazy DFA
/// handles assertion-free expressions; other cases retain the span engine's
/// acceptance rules. Construct one matcher per consumer, outside its record loop.
struct RecordMatcher {
  pattern : Pattern
  mut dfa : EngineCache[RecordDfa]
  mut span_plan : EngineCache[SpanPlan]
  mut span_dfa : EngineCache[SpanDfa]
  byte_literal : Bytes?
}

///|
pub fn Pattern::record_matcher(self : Pattern) -> RecordMatcher {
  {
    pattern: self,
    dfa: Uninitialized,
    span_plan: Uninitialized,
    span_dfa: Uninitialized,
    byte_literal: self.literal.map(literal => bytes(literal.text)),
  }
}

///|
/// Every matching record contains this literal. An empty result provides no
/// rejection guarantee. This is a filter only, never a substitute for matching.
pub fn RecordMatcher::required_literal(self : RecordMatcher) -> Bytes {
  self.pattern.required_literal
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
  if !whole && !word && self.dfa is Uninitialized {
    self.dfa = engine_cache(RecordDfa::new(self.pattern))
  }
  if !whole && !word && self.dfa is Ready(dfa) {
    let result = if required.is_empty() && value.length() >= 256 {
      dfa.matches_accelerated(value)
    } else {
      dfa.matches(value)
    }
    match result {
      Some(result) => return result
      None => self.dfa = Disabled
    }
  }
  self.find_span(text(value), whole~, word~) is Some(_)
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
  if self.pattern.literal is None && self.span_plan is Uninitialized {
    self.span_plan = engine_cache(SpanPlan::new(self.pattern))
  }
  if self.span_plan is Ready(plan) {
    return plan.find(self.pattern, value[:], start, whole, word)
  }
  self.pattern.find_span(value, start~, whole~, word~)
}

///|
priv struct RecordState {
  nodes : Array[Int32]
}

///|
priv struct RecordDfa {
  pattern : Pattern
  classes : FixedArray[Int32]
  representatives : Array[Int32]
  states : Array[RecordState]
  ids : Map[Array[Int32], Int32]
  edges : FixedArray[Int32]
  skip_plans : FixedArray[RecordSkip?]
  skip_planned : FixedArray[Bool]
  mut skip_budget : Int32
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
  let (classes, representatives) = byte_classes(pattern.program)
  let dfa = RecordDfa::{
    pattern,
    classes,
    representatives,
    states: [],
    ids: Map([]),
    edges: FixedArray::make(256 * representatives.length(), -1),
    skip_plans: FixedArray::make(256, None),
    skip_planned: FixedArray::make(256, false),
    skip_budget: 8,
  }
  let nodes = dfa.closure([pattern.entry])
  dfa.states.push({ nodes, })
  dfa.ids[nodes] = 0
  Some(dfa)
}

///|
fn byte_classes(
  program : Array[Instruction],
) -> (FixedArray[Int32], Array[Int32]) {
  let classes = FixedArray::make(256, 0)
  for instruction in program {
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
  (classes, representatives)
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
  row_offset : Int32,
  class : Int32,
) -> Int32 {
  let width = self.representatives.length()
  let row = self.states[row_offset / width]
  let slot = row_offset + class
  if self.edges[slot] != -1 {
    return self.edges[slot]
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
    self.edges[slot] = -2
    return -2
  }
  if self.ids.get(nodes) is Some(existing) {
    self.edges[slot] = existing * width
    return existing * width
  }
  if self.states.length() >= 256 {
    return -3
  }
  let next = self.states.length()
  self.ids[nodes] = next
  self.states.push({ nodes, })
  self.edges[slot] = next * width
  next * width
}

///|
#inline
fn RecordDfa::matches_accelerated(self : RecordDfa, value : BytesView) -> Bool? {
  if self.states[0].nodes[0] == 0 {
    return Some(true)
  }
  let mut state = 0
  let mut index = 0
  while index < value.length() {
    if (index & 15) == 0 && value.length() - index >= 32 {
      if self.skip_plan(state) is Some(plan) {
        index = plan.advance(value, index)
        if index == value.length() {
          break
        }
      }
    }
    let byte = value[index]
    let class = self.classes[byte.to_int()]
    let edge = self.edges[state + class]
    let next = if edge == -1 { self.transition(state, class) } else { edge }
    if next == -2 {
      return Some(true)
    }
    if next == -3 {
      return None
    }
    state = next
    index += 1
  }
  Some(false)
}

///|
// A mandatory-literal rejection pass already filters these records. Keep its
// original small scalar DFA loop without per-byte accelerator bookkeeping.
#inline
fn RecordDfa::matches(self : RecordDfa, value : BytesView) -> Bool? {
  if self.states[0].nodes[0] == 0 {
    return Some(true)
  }
  let mut state = 0
  for byte in value {
    let class = self.classes[byte.to_int()]
    let edge = self.edges[state + class]
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
