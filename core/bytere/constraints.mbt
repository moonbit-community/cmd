///|
priv struct ConstraintCompiler {
  program : Array[Instruction]
  conditions : Array[Array[Assertion]]
  empty_next : Array[Int32]
  copies : Map[(Int32, Array[Assertion]), Int32]
}

///|
// Context belongs to each epsilon-path copy. Consuming a byte drops it;
// an empty reference retains it. Reusing single-successor copies changes the
// first closing-node choice when counted captures and anchors overlap.
fn ConstraintCompiler::copy(
  self : ConstraintCompiler,
  pc : Int32,
  conditions : Array[Assertion],
  root : Int32,
  reuse~ : Bool = false,
) -> Int32 {
  let key = (pc, conditions)
  if reuse && self.copies.get(key) is Some(index) {
    return index
  }
  let instruction = self.program[pc]
  let index = self.program.length()
  self.copies[key] = index
  self.program.push(Accept)
  self.conditions.push(conditions)
  self.empty_next.push(0)
  self.program[index] = match instruction {
    Split(a, b) =>
      Split(
        self.copy(a, conditions, root, reuse=true),
        self.copy(b, conditions, root),
      )
    Save(slot, next) => Save(slot, self.copy(next, conditions, root))
    SaveOptional(group, next) =>
      SaveOptional(group, self.copy(next, conditions, root))
    Assert(assertion, next) => {
      let combined = conditions.copy()
      if !combined.contains(assertion) {
        combined.push(assertion)
      }
      Assert(
        assertion,
        if pc == root {
          next
        } else {
          self.copy(next, combined, root)
        },
      )
    }
    Reference(group, next) => {
      self.empty_next[index] = self.copy(next, conditions, root)
      Reference(group, next)
    }
    _ => instruction
  }
  index
}

///|
fn constrain_program(
  program : Array[Instruction],
) -> (Array[Array[Assertion]], Array[Int32]) {
  let original = program.length()
  let compiler = ConstraintCompiler::{
    program,
    conditions: Array::makei(original, _ => []),
    empty_next: Array::makei(original, index => {
      match program[index] {
        Reference(_, next) => next
        _ => 0
      }
    }),
    copies: Map([]),
  }
  for pc = original - 1; pc >= 0; pc = pc - 1 {
    if program[pc] is Assert(assertion, next) {
      program[pc] = Assert(assertion, compiler.copy(next, [assertion], pc))
    }
  }
  (compiler.conditions, compiler.empty_next)
}

///|
fn Pattern::allows(
  self : Pattern,
  value : StringView,
  pc : Int32,
  position : Int32,
) -> Bool {
  self.conditions[pc].all(assertion => assertion.holds(value, position))
}

///|
fn Pattern::previous_allows(
  self : Pattern,
  value : StringView,
  pc : Int32,
  position : Int32,
) -> Bool {
  self.conditions[pc].all(assertion => {
    assertion is (End | LineEnd) || assertion.holds(value, position)
  })
}

///|
fn Pattern::node_order(self : Pattern, pc : Int32) -> Int32 {
  if pc < self.original_nodes {
    self.original_nodes - 1 - pc
  } else {
    pc
  }
}

///|
fn Pattern::ordered_nodes(
  self : Pattern,
  nodes : Map[Int32, Bool],
) -> Array[Int32] {
  let ordered = nodes.keys().to_array()
  ordered.sort_by((a, b) => self.node_order(a).compare(self.node_order(b)))
  ordered
}
