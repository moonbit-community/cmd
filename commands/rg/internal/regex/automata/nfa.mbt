///|
/// A single byte range transition.
pub(all) struct Transition {
  start : Int32
  end : Int32
  next : Int32
} derive(Debug, Eq)

///|
/// A state in a Thompson NFA.
pub(all) enum State {
  ByteRange(Int32, Int32, Int32)
  Sparse(Array[Transition])
  Look(@syntax.Look, Int32)
  Union(Array[Int32])
  BinaryUnion(Int32, Int32)
  Capture(next~ : Int32, group~ : Int32, slot~ : Int32)
  Fail
  Match
} derive(Debug, Eq)

///|
pub fn State::is_epsilon(self : State) -> Bool {
  match self {
    ByteRange(_, _, _) | Sparse(_) | Fail | Match => false
    Look(_, _) | Union(_) | BinaryUnion(_, _) | Capture(..) => true
  }
}

///|
/// A Thompson NFA over bytes.
pub struct NFA {
  states : Array[State]
  start_anchored : Int32
  start_unanchored : Int32
  reverse : Bool
  /// Number of capture groups, including the implicit group 0.
  group_len : Int32
  /// Names of capture groups, indexed by group index.
  group_names : Array[String?]
  /// The union of all look-around assertions in this NFA.
  look_set_any : @syntax.LookSet
  /// Whether the regex can match the empty string.
  has_empty : Bool
  /// Byte equivalence classes, as a 256 entry map from byte to class.
  byte_classes : FixedArray[Int32]
  byte_class_len : Int32
}

///|
pub fn NFA::states(self : NFA) -> Array[State] {
  self.states
}

///|
pub fn NFA::start_anchored(self : NFA) -> Int32 {
  self.start_anchored
}

///|
pub fn NFA::start_unanchored(self : NFA) -> Int32 {
  self.start_unanchored
}

///|
pub fn NFA::group_len(self : NFA) -> Int32 {
  self.group_len
}

///|
pub fn NFA::group_names(self : NFA) -> Array[String?] {
  self.group_names
}

///|
pub fn NFA::look_set_any(self : NFA) -> @syntax.LookSet {
  self.look_set_any
}

///|
pub fn NFA::is_reverse(self : NFA) -> Bool {
  self.reverse
}

///|
pub fn NFA::to_string(self : NFA) -> String {
  let buf = StringBuilder()
  for i, s in self.states {
    let marker = if i == self.start_anchored {
      "^"
    } else if i == self.start_unanchored {
      ">"
    } else {
      " "
    }
    buf.write_string("\{marker}\{i}: ")
    match s {
      ByteRange(a, b, n) => buf.write_string("\{show_range(a, b)} => \{n}")
      Sparse(ts) =>
        buf.write_string(
          "sparse(" +
          ts.map(t => "\{show_range(t.start, t.end)} => \{t.next}").join(", ") +
          ")",
        )
      Look(l, n) => buf.write_string("\{Repr(l)} => \{n}")
      Union(alts) =>
        buf.write_string(
          "union(" + alts.map(a => a.to_string()).join(", ") + ")",
        )
      BinaryUnion(a, b) => buf.write_string("binary-union(\{a}, \{b})")
      Capture(next~, group~, slot~) =>
        buf.write_string("capture(group=\{group}, slot=\{slot}) => \{next}")
      Fail => buf.write_string("FAIL")
      Match => buf.write_string("MATCH")
    }
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
fn show_byte(b : Int32) -> String {
  if b >= 0x21 && b <= 0x7E && b != '\\' {
    b.unsafe_to_char().to_string()
  } else {
    let s = b.to_string(radix=16)
    if s.length() < 2 {
      "\\x0" + s
    } else {
      "\\x" + s
    }
  }
}

///|
fn show_range(a : Int32, b : Int32) -> String {
  if a == b {
    show_byte(a)
  } else {
    show_byte(a) + "-" + show_byte(b)
  }
}

///|
/// Builder states: like NFA states, but with `Empty` states used for
/// patching and union states whose alternates may be reversed.
priv enum BState {
  BEmpty(Int32)
  BByteRange(Int32, Int32, Int32)
  BSparse(Array[Transition])
  BLook(@syntax.Look, Int32)
  BUnion(Array[Int32])
  BUnionReverse(Array[Int32])
  BCaptureStart(Int32, Int32)
  BCaptureEnd(Int32, Int32)
  BFail
  BMatch
}

///|
priv struct Builder {
  states : Array[BState]
  size_limit : Int32?
  // Heap memory used by states, accounted like regex-automata's builder
  // (8 bytes per sparse transition, 4 per union alternate).
  mut memory_states : Int32
}

///|
fn Builder::add(self : Builder, s : BState) -> Int32 {
  let id = self.states.length()
  self.memory_states += match s {
    BSparse(trans) => trans.length() * 8
    BUnion(alts) | BUnionReverse(alts) => alts.length() * 4
    _ => 0
  }
  self.states.push(s)
  id
}

///|
fn Builder::add_empty(self : Builder) -> Int32 {
  self.add(BEmpty(0))
}

///|
fn Builder::add_sparse(self : Builder, trans : Array[Transition]) -> Int32 {
  self.add(BSparse(trans))
}

///|
fn Builder::patch(self : Builder, from : Int32, to : Int32) -> Unit {
  match self.states[from] {
    BEmpty(_) => self.states[from] = BEmpty(to)
    BByteRange(a, b, _) => self.states[from] = BByteRange(a, b, to)
    BSparse(_) => abort("cannot patch sparse state")
    BLook(l, _) => self.states[from] = BLook(l, to)
    BUnion(alts) | BUnionReverse(alts) => {
      alts.push(to)
      self.memory_states += 4
    }
    BCaptureStart(g, _) => self.states[from] = BCaptureStart(g, to)
    BCaptureEnd(g, _) => self.states[from] = BCaptureEnd(g, to)
    BFail | BMatch => ()
  }
}

///|
/// An error that occurs when building an NFA.
pub suberror BuildError {
  TooBig(Int32)
} derive(Debug)

///|
fn Builder::check_size(self : Builder) -> Unit raise BuildError {
  // Like regex-automata's `Builder::memory_usage`, with 32-byte states (the
  // size of its `State` on 64-bit targets).
  let usage = self.states.length().to_int64() * 32 +
    self.memory_states.to_int64()
  if self.size_limit is Some(limit) && usage > limit.to_int64() {
    raise TooBig(limit)
  }
}

///|
fn Builder::build(
  self : Builder,
  start_anchored : Int32,
  start_unanchored : Int32,
  reverse : Bool,
  group_len : Int32,
  group_names : Array[String?],
) -> NFA {
  let n = self.states.length()
  // Resolve each builder state to a final state, skipping empties.
  let remap = FixedArray::make(n, -1)
  let out : Array[State] = []
  // First pass: assign IDs to all non-empty states.
  let is_empty = FixedArray::make(n, false)
  for i in 0..<n {
    match self.states[i] {
      BEmpty(_) => is_empty[i] = true
      BUnion(alts) | BUnionReverse(alts) if alts.length() == 1 =>
        is_empty[i] = true
      _ => {
        remap[i] = out.length()
        out.push(Fail) // placeholder
      }
    }
  }
  fn resolve(id : Int32) -> Int32 {
    let mut cur = id
    let mut steps = 0
    while is_empty[cur] && steps <= n {
      cur = match self.states[cur] {
        BEmpty(next) => next
        BUnion(alts) | BUnionReverse(alts) => alts[0]
        _ => abort("unreachable")
      }
      steps += 1
    }
    if is_empty[cur] {
      // A cycle of empty states can never match anything.
      -1
    } else {
      remap[cur]
    }
  }

  let fail_id = Ref(-1)
  fn target(id : Int32) -> Int32 {
    let r = resolve(id)
    if r >= 0 {
      r
    } else {
      if fail_id.val < 0 {
        fail_id.val = out.length()
        out.push(Fail)
      }
      fail_id.val
    }
  }

  let mut looks = @syntax.LookSet::empty()
  for i in 0..<n {
    if remap[i] < 0 {
      continue
    }
    let s : State = match self.states[i] {
      BEmpty(_) => abort("unreachable")
      BByteRange(a, b, next) => ByteRange(a, b, target(next))
      BSparse(ts) =>
        match ts.length() {
          0 => Fail
          1 => ByteRange(ts[0].start, ts[0].end, target(ts[0].next))
          _ =>
            Sparse(
              ts.map(t => { start: t.start, end: t.end, next: target(t.next), }),
            )
        }
      BLook(l, next) => {
        looks = looks.insert(l)
        Look(l, target(next))
      }
      BUnion(alts) =>
        match alts.length() {
          0 => Fail
          2 => BinaryUnion(target(alts[0]), target(alts[1]))
          _ => Union(alts.map(a => target(a)))
        }
      BUnionReverse(alts) => {
        let rev = alts.rev()
        match rev.length() {
          0 => Fail
          2 => BinaryUnion(target(rev[0]), target(rev[1]))
          _ => Union(rev.map(a => target(a)))
        }
      }
      BCaptureStart(group, next) =>
        Capture(next=target(next), group~, slot=group * 2)
      BCaptureEnd(group, next) =>
        Capture(next=target(next), group~, slot=group * 2 + 1)
      BFail => Fail
      BMatch => Match
    }
    out[remap[i]] = s
  }
  let sa = target(start_anchored)
  let su = target(start_unanchored)
  let (classes, class_len) = compute_byte_classes(out, looks)
  {
    states: out,
    start_anchored: sa,
    start_unanchored: su,
    reverse,
    group_len,
    group_names,
    look_set_any: looks,
    has_empty: false,
    byte_classes: classes,
    byte_class_len: class_len,
  }
}

///|
/// Computes byte equivalence classes: two bytes are in the same class if
/// no transition and no look-around assertion can distinguish them.
fn compute_byte_classes(
  states : Array[State],
  looks : @syntax.LookSet,
) -> (FixedArray[Int32], Int32) {
  // boundaries[b] is true if a new class starts at byte b.
  let boundaries = FixedArray::make(257, false)
  fn set_range(a : Int32, b : Int32) {
    boundaries[a] = true
    boundaries[b + 1] = true
  }

  for s in states {
    match s {
      ByteRange(a, b, _) => set_range(a, b)
      Sparse(ts) =>
        for t in ts {
          set_range(t.start, t.end)
        }
      _ => ()
    }
  }
  if looks.contains_anchor_line() {
    set_range('\n', '\n')
  }
  if looks.contains_anchor_crlf() {
    set_range('\r', '\r')
    set_range('\n', '\n')
  }
  if looks.contains_word() {
    set_range('0', '9')
    set_range('A', 'Z')
    set_range('_', '_')
    set_range('a', 'z')
  }
  if looks.contains_word_unicode() {
    set_range(0x80, 0xFF)
  }
  let classes = FixedArray::make(256, 0)
  let mut class = 0
  for b in 0..<256 {
    if b > 0 && boundaries[b] {
      class += 1
    }
    classes[b] = class
  }
  (classes, class + 1)
}

///|
priv struct ThompsonRef {
  start : Int32
  end : Int32
}

///|
/// Configuration for compiling an HIR to an NFA.
pub(all) struct NFAConfig {
  reverse : Bool
  captures : Bool
  unanchored_prefix : Bool
  size_limit : Int32?
}

///|
pub fn NFAConfig::default() -> NFAConfig {
  { reverse: false, captures: true, unanchored_prefix: true, size_limit: None, }
}

///|
priv struct Compiler {
  builder : Builder
  config : NFAConfig
  group_names : Map[Int32, String]
  mut max_group : Int32
}

///|
/// Compiles the given HIR into a Thompson NFA.
pub fn compile_nfa(
  hir : @syntax.Hir,
  config~ : NFAConfig = NFAConfig::default(),
) -> NFA raise BuildError {
  let c : Compiler = {
    builder: { states: [], size_limit: config.size_limit, memory_states: 0, },
    config,
    group_names: {},
    max_group: 0,
  }
  let props = hir.props
  let all_anchored = if config.reverse {
    props.look_set_suffix.contains(End)
  } else {
    props.look_set_prefix.contains(Start)
  }
  let anchored = !config.unanchored_prefix || all_anchored
  let prefix = if anchored {
    c.c_empty()
  } else {
    c.c_at_least(@syntax.Hir::dot(AnyByte), false, 0)
  }
  let one = c.c_cap(0, None, hir)
  let m = c.builder.add(BMatch)
  c.builder.patch(one.end, m)
  c.builder.patch(prefix.end, one.start)
  c.builder.check_size()
  let group_len = c.max_group + 1
  let names = Array::makei(group_len, i => c.group_names.get(i))
  c.builder.build(one.start, prefix.start, config.reverse, group_len, names)
}

///|
fn Compiler::c(
  self : Compiler,
  h : @syntax.Hir,
) -> ThompsonRef raise BuildError {
  self.builder.check_size()
  match h.kind {
    Empty => self.c_empty()
    Literal(bytes) => {
      let refs = []
      for b in bytes {
        refs.push(self.c_range(b.to_int(), b.to_int()))
      }
      self.c_concat_refs(refs)
    }
    Class(Bytes(ranges)) => self.c_byte_class(ranges)
    Class(Unicode(ranges)) => self.c_unicode_class(ranges)
    Look(look) => {
      let l = if self.config.reverse { look.reversed() } else { look }
      let id = self.builder.add(BLook(l, 0))
      { start: id, end: id, }
    }
    Repetition(min~, max~, greedy~, sub) =>
      match (min, max) {
        (0, Some(1)) => self.c_zero_or_one(sub, greedy)
        (min, None) => self.c_at_least(sub, greedy, min)
        (min, Some(max)) if min == max => self.c_exactly(sub, min)
        (min, Some(max)) => self.c_bounded(sub, greedy, min, max)
      }
    Capture(index~, name~, sub) => self.c_cap(index, name, sub)
    Concat(xs) => {
      let refs = []
      if self.config.reverse {
        for i = xs.length() - 1; i >= 0; i = i - 1 {
          refs.push(self.c(xs[i]))
        }
      } else {
        for x in xs {
          refs.push(self.c(x))
        }
      }
      self.c_concat_ordered(refs)
    }
    Alternation(xs) => {
      let refs = []
      for x in xs {
        refs.push(self.c(x))
      }
      self.c_alt(refs)
    }
  }
}

///|
/// Concatenates refs given in forward order, reversing them if this is a
/// reverse compiler.
fn Compiler::c_concat_refs(
  self : Compiler,
  refs : Array[ThompsonRef],
) -> ThompsonRef {
  if self.config.reverse {
    self.c_concat_ordered(refs.rev())
  } else {
    self.c_concat_ordered(refs)
  }
}

///|
fn Compiler::c_concat_ordered(
  self : Compiler,
  refs : Array[ThompsonRef],
) -> ThompsonRef {
  if refs.is_empty() {
    return self.c_empty()
  }
  let start = refs[0].start
  let mut end = refs[0].end
  for i in 1..<refs.length() {
    self.builder.patch(end, refs[i].start)
    end = refs[i].end
  }
  { start, end, }
}

///|
fn Compiler::c_alt(self : Compiler, refs : Array[ThompsonRef]) -> ThompsonRef {
  if refs.is_empty() {
    return self.c_fail()
  }
  if refs.length() == 1 {
    return refs[0]
  }
  let union = self.builder.add(BUnion([]))
  let end = self.builder.add_empty()
  for r in refs {
    self.builder.patch(union, r.start)
    self.builder.patch(r.end, end)
  }
  { start: union, end, }
}

///|
fn Compiler::c_cap(
  self : Compiler,
  index : Int32,
  name : String?,
  sub : @syntax.Hir,
) -> ThompsonRef raise BuildError {
  if !self.config.captures {
    return self.c(sub)
  }
  if index > self.max_group {
    self.max_group = index
  }
  if name is Some(n) {
    self.group_names[index] = n
  }
  let start = self.builder.add(BCaptureStart(index, 0))
  let inner = self.c(sub)
  let end = self.builder.add(BCaptureEnd(index, 0))
  self.builder.patch(start, inner.start)
  self.builder.patch(inner.end, end)
  { start, end, }
}

///|
fn Compiler::add_union(self : Compiler, greedy : Bool) -> Int32 {
  if greedy {
    self.builder.add(BUnion([]))
  } else {
    self.builder.add(BUnionReverse([]))
  }
}

///|
fn Compiler::c_bounded(
  self : Compiler,
  sub : @syntax.Hir,
  greedy : Bool,
  min : Int32,
  max : Int32,
) -> ThompsonRef raise BuildError {
  let prefix = self.c_exactly(sub, min)
  if min == max {
    return prefix
  }
  let empty = self.builder.add_empty()
  let mut prev_end = prefix.end
  for _ in min..<max {
    let union = self.add_union(greedy)
    let compiled = self.c(sub)
    self.builder.patch(prev_end, union)
    self.builder.patch(union, compiled.start)
    self.builder.patch(union, empty)
    prev_end = compiled.end
  }
  self.builder.patch(prev_end, empty)
  { start: prefix.start, end: empty, }
}

///|
fn Compiler::c_at_least(
  self : Compiler,
  sub : @syntax.Hir,
  greedy : Bool,
  n : Int32,
) -> ThompsonRef raise BuildError {
  if n == 0 {
    if sub.props.minimum_len is Some(len) && len > 0 {
      let union = self.add_union(greedy)
      let compiled = self.c(sub)
      self.builder.patch(union, compiled.start)
      self.builder.patch(compiled.end, union)
      return { start: union, end: union, }
    }
    let compiled = self.c(sub)
    let plus = self.add_union(greedy)
    self.builder.patch(compiled.end, plus)
    self.builder.patch(plus, compiled.start)
    let question = self.add_union(greedy)
    let empty = self.builder.add_empty()
    self.builder.patch(question, compiled.start)
    self.builder.patch(question, empty)
    self.builder.patch(plus, empty)
    { start: question, end: empty, }
  } else if n == 1 {
    let compiled = self.c(sub)
    let union = self.add_union(greedy)
    self.builder.patch(compiled.end, union)
    self.builder.patch(union, compiled.start)
    { start: compiled.start, end: union, }
  } else {
    let prefix = self.c_exactly(sub, n - 1)
    let last = self.c(sub)
    let union = self.add_union(greedy)
    self.builder.patch(prefix.end, last.start)
    self.builder.patch(last.end, union)
    self.builder.patch(union, last.start)
    { start: prefix.start, end: union, }
  }
}

///|
fn Compiler::c_zero_or_one(
  self : Compiler,
  sub : @syntax.Hir,
  greedy : Bool,
) -> ThompsonRef raise BuildError {
  let union = self.add_union(greedy)
  let compiled = self.c(sub)
  let empty = self.builder.add_empty()
  self.builder.patch(union, compiled.start)
  self.builder.patch(union, empty)
  self.builder.patch(compiled.end, empty)
  { start: union, end: empty, }
}

///|
fn Compiler::c_exactly(
  self : Compiler,
  sub : @syntax.Hir,
  n : Int32,
) -> ThompsonRef raise BuildError {
  let refs = []
  for _ in 0..<n {
    refs.push(self.c(sub))
  }
  self.c_concat_ordered(refs)
}

///|
fn Compiler::c_byte_class(
  self : Compiler,
  ranges : Array[(Int32, Int32)],
) -> ThompsonRef {
  let end = self.builder.add_empty()
  let trans = ranges.map(r => { start: r.0, end: r.1, next: end, })
  { start: self.builder.add_sparse(trans), end, }
}

///|
fn Compiler::c_unicode_class(
  self : Compiler,
  ranges : Array[(Int32, Int32)],
) -> ThompsonRef {
  if ranges.is_empty() || ranges[ranges.length() - 1].1 <= 0x7F {
    return self.c_byte_class(ranges)
  }
  if self.config.reverse {
    // Compile each sequence in reverse, sharing common suffixes.
    let cache : Map[(Int32, Int32, Int32), Int32] = Map([])
    let union = self.builder.add(BUnion([]))
    let alt_end = self.builder.add_empty()
    for r in ranges {
      for seq in utf8_sequences(r.0, r.1) {
        let mut end = alt_end
        for br in seq {
          let key = (end, br.0, br.1)
          match cache.get(key) {
            Some(id) => end = id
            None => {
              let id = self.builder.add(BByteRange(br.0, br.1, end))
              cache[key] = id
              end = id
            }
          }
        }
        self.builder.patch(union, end)
      }
    }
    { start: union, end: alt_end, }
  } else {
    let utf8c = Utf8Compiler::new(self.builder)
    for r in ranges {
      for seq in utf8_sequences(r.0, r.1) {
        utf8c.add(seq)
      }
    }
    utf8c.finish()
  }
}

///|
fn Compiler::c_range(
  self : Compiler,
  start : Int32,
  end : Int32,
) -> ThompsonRef {
  let id = self.builder.add(BByteRange(start, end, 0))
  { start: id, end: id, }
}

///|
fn Compiler::c_empty(self : Compiler) -> ThompsonRef {
  let id = self.builder.add_empty()
  { start: id, end: id, }
}

///|
fn Compiler::c_fail(self : Compiler) -> ThompsonRef {
  let id = self.builder.add(BFail)
  { start: id, end: id, }
}
