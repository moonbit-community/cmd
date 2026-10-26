///|
/// The reverse unanchored automaton marks every feasible start. The forward
/// anchored automaton then selects the longest endpoint at the earliest start.
/// This avoids assuming that the first accepting endpoint is leftmost-longest.
priv struct SpanDfa {
  reverse : EndpointDfa
  forward : EndpointDfa
}

///|
priv struct EndpointDfa {
  arcs : Array[Array[(Instruction, Int32)]]
  epsilon : Array[Array[Int32]]
  entry : Int32
  accept : Int32
  restart : Bool
  classes : FixedArray[Int32]
  representatives : Array[Int32]
  states : Array[Array[Int32]]
  ids : Map[Array[Int32], Int32]
  edges : FixedArray[Int32]
  accepting : FixedArray[Bool]
}

///|
fn SpanDfa::new(pattern : Pattern) -> SpanDfa? {
  if pattern.literal is Some(_) ||
    pattern.program.length() > 256 ||
    pattern.backreferences ||
    pattern.program.iter().any(instruction => instruction is Assert(_, _)) {
    return None
  }
  let (classes, representatives) = byte_classes(pattern.program)
  Some({
    reverse: EndpointDfa::new(pattern, true, classes, representatives),
    forward: EndpointDfa::new(pattern, false, classes, representatives),
  })
}

///|
fn EndpointDfa::new(
  pattern : Pattern,
  reverse : Bool,
  classes : FixedArray[Int32],
  representatives : Array[Int32],
) -> EndpointDfa {
  let arcs : Array[Array[(Instruction, Int32)]] = Array::makei(
    pattern.program.length(),
    _ => [],
  )
  let epsilon : Array[Array[Int32]] = Array::makei(pattern.program.length(), _ => {
    []
  })
  for pc, instruction in pattern.program {
    match instruction {
      Byte(_, next) | Class(_, next) | Any(next) =>
        if reverse {
          arcs[next].push((instruction, pc))
        } else {
          arcs[pc].push((instruction, next))
        }
      Split(first, second) =>
        if reverse {
          epsilon[first].push(pc)
          epsilon[second].push(pc)
        } else {
          epsilon[pc].append([first, second])
        }
      Save(_, next) | SaveOptional(_, next) =>
        if reverse {
          epsilon[next].push(pc)
        } else {
          epsilon[pc].push(next)
        }
      Accept => ()
      _ => abort("unsupported instruction in endpoint DFA")
    }
  }
  let self : EndpointDfa = {
    arcs,
    epsilon,
    entry: if reverse {
      0
    } else {
      pattern.entry
    },
    accept: if reverse {
      pattern.entry
    } else {
      0
    },
    restart: reverse,
    classes,
    representatives,
    states: [],
    ids: Map([]),
    edges: FixedArray::make(256 * representatives.length(), -1),
    accepting: FixedArray::make(256 * representatives.length(), false),
  }
  let initial = self.closure([self.entry])
  self.accepting[0] = initial.contains(self.accept)
  self.states.push(initial)
  self.ids[initial] = 0
  self
}

///|
fn EndpointDfa::closure(
  self : EndpointDfa,
  stack : Array[Int32],
) -> Array[Int32] {
  let seen = FixedArray::make(self.arcs.length(), false)
  let nodes : Array[Int32] = []
  while stack.pop() is Some(pc) {
    if seen[pc] {
      continue
    }
    seen[pc] = true
    if pc == self.accept || !self.arcs[pc].is_empty() {
      nodes.push(pc)
    }
    stack.append(self.epsilon[pc])
  }
  nodes.sort()
  nodes
}

///|
fn EndpointDfa::transition(
  self : EndpointDfa,
  state : Int32,
  class : Int32,
) -> Int32 {
  let width = self.representatives.length()
  let byte = self.representatives[class]
  let seeds : Array[Int32] = if self.restart { [self.entry] } else { [] }
  for pc in self.states[state / width] {
    for (instruction, next) in self.arcs[pc] {
      if instruction.consumes(byte) {
        seeds.push(next)
      }
    }
  }
  let nodes = self.closure(seeds)
  let target = if nodes.is_empty() {
    -2
  } else if self.ids.get(nodes) is Some(id) {
    id * width
  } else {
    if self.states.length() >= 256 {
      return -3
    }
    let id = self.states.length()
    self.ids[nodes] = id
    self.states.push(nodes)
    self.accepting[id * width] = nodes.contains(self.accept)
    id * width
  }
  self.edges[state + class] = target
  target
}

///|
#inline
fn EndpointDfa::step(self : EndpointDfa, state : Int32, byte : Byte) -> Int32 {
  let class = self.classes[byte.to_int()]
  let cached = self.edges[state + class]
  if cached == -1 {
    self.transition(state, class)
  } else {
    cached
  }
}

///|
fn SpanDfa::starts(self : SpanDfa, value : BytesView) -> FixedArray[UInt64]? {
  let bits = FixedArray::make(value.length() / 64 + 1, 0UL)
  let mut state = 0
  if self.reverse.accepting[state] {
    bits[value.length() / 64] = bits[value.length() / 64] |
      (1UL << (value.length() % 64))
  }
  for position = value.length() - 1; position >= 0; position = position - 1 {
    state = self.reverse.step(state, value[position])
    if state == -3 {
      return None
    }
    if state == -2 {
      break
    }
    if self.reverse.accepting[state] {
      bits[position / 64] = bits[position / 64] | (1UL << (position % 64))
    }
  }
  Some(bits)
}

///|
fn next_start(bits : FixedArray[UInt64], start : Int32) -> Int32? {
  let mut block = start / 64
  let mut word = bits[block] & (0xFFFFFFFFFFFFFFFFUL << (start % 64))
  for ;; {
    if word != 0UL {
      return Some(block * 64 + word.ctz())
    }
    block += 1
    if block == bits.length() {
      return None
    }
    word = bits[block]
  }
}

///|
fn SpanDfa::longest(self : SpanDfa, value : BytesView, start : Int32) -> Int32 {
  let mut state = 0
  let mut best = if self.forward.accepting[0] { start } else { -1 }
  for position in start..<value.length() {
    state = self.forward.step(state, value[position])
    if state == -3 {
      return -3
    }
    if state == -2 {
      break
    }
    if self.forward.accepting[state] {
      best = position + 1
    }
  }
  best
}
