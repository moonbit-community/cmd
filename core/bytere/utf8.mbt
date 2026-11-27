///|
/// POSIX grep grammar compiled with scalar predicates and original byte offsets.
pub struct Utf8Pattern {
  priv program : Array[Instruction]
  priv sets : Array[ScalarSet]
  priv entry : Int32
  priv captures : Array[Pattern]
}

///|
pub fn compile_utf8(
  patterns : Array[String],
  fixed~ : Bool,
  extended~ : Bool,
  ignore_case~ : Bool,
) -> Utf8Pattern raise {
  let sets = []
  let regular = []
  let captures = []
  for pattern in patterns {
    let parser : Parser = {
      source: pattern,
      scalar_sets: Some(sets),
      extended,
      emacs: false,
      grep_syntax: true,
      ignore_case,
      index: 0,
      closed: [],
      backreferences: false,
      depth: 0,
    }
    let tree = if fixed {
      Sequence(pattern.iter().map(c => parser.literal(c.to_int())).collect())
    } else {
      let tree = parser.expression()
      guard parser.index == pattern.length() else {
        raise PatternError("unmatched closing parenthesis")
      }
      tree
    }
    if parser.backreferences {
      // Each -e expression owns its group numbers and register-selection graph.
      let program = [Instruction::Accept]
      let entry = tree.emit(program, 0)
      let original_nodes = program.length()
      let (conditions, empty_next) = constrain_program(program)
      captures.push(Pattern::{
        program,
        entry,
        groups: parser.closed.length(),
        backreferences: true,
        ignore_case,
        literal: None,
        prefix: "",
        required_literal: b"",
        original_nodes,
        conditions,
        empty_next,
      })
    } else {
      regular.push(tree)
    }
  }
  let program = [Instruction::Accept]
  let entry = if regular.is_empty() {
    -1
  } else {
    Tree::Choice(regular).emit(program, 0)
  }
  { program, sets, entry, captures, }
}

///|
pub struct Utf8Record {
  priv chars : Array[Char?]
  priv offsets : Array[Int32]
  priv words : Array[Bool]
}

///|
pub fn Utf8Record::new(bytes : BytesView) -> Utf8Record {
  let chars = []
  let offsets = [0]
  let words = []
  for i = 0; i < bytes.length(); {
    let (c, n) = @textwidth.Profile::Utf8.next(bytes, i)
    chars.push(c)
    words.push(scalar_word(c))
    offsets.push(i + n)
    continue i + n
  }
  { chars, offsets, words, }
}

///|
fn Utf8Record::assertion(
  self : Utf8Record,
  assertion : Assertion,
  i : Int32,
) -> Bool {
  let left = i > 0 && self.words[i - 1]
  let right = i < self.words.length() && self.words[i]
  match assertion {
    Begin => i == 0
    End => i == self.chars.length()
    LineBegin => i == 0 || self.chars[i - 1] is Some('\n')
    LineEnd => i == self.chars.length() || self.chars[i] is Some('\n')
    WordBegin => !left && right
    WordEnd => left && !right
    WordBoundary => left != right
    NotWordBoundary => left == right
  }
}

///|
/// Propagate the earliest start arriving at each instruction. Two paths at the
/// same position and instruction have identical futures in a regular language.
fn Utf8Pattern::regular(
  self : Utf8Pattern,
  record : Utf8Record,
  start : Int32,
  whole : Bool,
  word : Bool,
) -> (Int32, Int32)? {
  let mut active : Map[Int32, Int32] = Map([])
  let mut best : (Int32, Int32)? = None
  for i in start..<=record.chars.length() {
    if best is None &&
      (!whole || i == 0) &&
      (!word || i == 0 || !record.words[i - 1]) {
      if !active.contains(self.entry) {
        active[self.entry] = i
      }
    }
    let stack = active.keys().collect()
    let next : Map[Int32, Int32] = Map([])
    while stack.pop() is Some(pc) {
      let from = active[pc]
      if best is Some((old, _)) && from > old {
        continue
      }
      fn epsilon(dest : Int32) {
        if active.get(dest).map_or(true, old => from < old) {
          active[dest] = from
          stack.push(dest)
        }
      }
      fn advance(dest : Int32) {
        if next.get(dest).map_or(true, old => from < old) {
          next[dest] = from
        }
      }
      match self.program[pc] {
        Accept =>
          if (!whole || i == record.chars.length()) &&
            (!word || i == record.chars.length() || !record.words[i]) {
            if best.map_or(true, old => {
                from < old.0 || (from == old.0 && i > old.1)
              }) {
              best = Some((from, i))
            }
          }
        Byte(id, dest) =>
          if i < record.chars.length() &&
            self.sets[id].contains(record.chars[i]) {
            advance(dest)
          }
        Any(dest) =>
          if i < record.chars.length() && record.chars[i] is Some(_) {
            advance(dest)
          }
        Assert(a, dest) => if record.assertion(a, i) { epsilon(dest) }
        Split(a, b) => {
          epsilon(a)
          epsilon(b)
        }
        Save(_, dest) | SaveOptional(_, dest) => epsilon(dest)
        Class(_) | Reference(_) => abort("invalid scalar regular instruction")
      }
    }
    if next.is_empty() && (best is Some(_) || whole) {
      break
    }
    active = next
  }
  best
}

///|
pub fn Utf8Pattern::find_span(
  self : Utf8Pattern,
  record : Utf8Record,
  start~ : Int32 = 0,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> (Int32, Int32)? {
  guard start >= 0 &&
    start <= record.offsets.last().unwrap() &&
    (!whole || start == 0) else {
    return None
  }
  let mut lo = 0
  let mut hi = record.offsets.length() - 1
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if record.offsets[mid] < start {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let mut result = if self.entry >= 0 {
    self.regular(record, lo, whole, word)
  } else {
    None
  }
  let input = CaptureInput::ScalarText(record, self.sets)
  for pattern in self.captures {
    for i in lo..<=record.chars.length() {
      if result is Some((start, _)) && start < i {
        break
      }
      match pattern.reference_result(input, i, whole, word, true) {
        Matched(hit) => {
          if result.map_or(true, old => {
              i < old.0 || (i == old.0 && hit.end > old.1)
            }) {
            result = Some((i, hit.end))
          }
          break
        }
        InvalidSelection => break
        Miss => ()
      }
      if whole {
        break
      }
    }
  }
  result.map(hit => (record.offsets[hit.0], record.offsets[hit.1]))
}
