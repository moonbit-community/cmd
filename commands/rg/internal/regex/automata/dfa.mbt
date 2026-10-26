///|
/// A state in the lazy DFA.
priv struct DState {
  nfa_ids : Array[Int32]
  look_have : UInt32
  look_need : UInt32
  is_match : Bool
  is_from_word : Bool
  is_half_crlf : Bool
}

///|
fn DState::key(self : DState) -> String {
  let buf = StringBuilder()
  buf.write_string(self.look_have.to_string())
  buf.write_char(':')
  buf.write_string(self.look_need.to_string())
  buf.write_char(if self.is_match { 'M' } else { 'm' })
  buf.write_char(if self.is_from_word { 'W' } else { 'w' })
  buf.write_char(if self.is_half_crlf { 'C' } else { 'c' })
  for id in self.nfa_ids {
    buf.write_char(',')
    buf.write_string(id.to_string())
  }
  buf.to_string()
}

///|
/// Special results returned by DFA searches.
pub const DFA_NO_MATCH : Int32 = -1

///|
pub const DFA_FAILED : Int32 = -2

///|
let dead_id : Int32 = 0

///|
let quit_id : Int32 = 1

///|
/// The kind of look-behind context at the start of a search.
fn start_kind(byte : Int32, lineterm : Int32) -> Int32 {
  if byte < 0 {
    1 // Text
  } else if byte == lineterm && lineterm != '\n' && lineterm != '\r' {
    5 // CustomLineTerminator
  } else if byte == '\n' {
    2 // LineLF
  } else if byte == '\r' {
    3 // LineCR
  } else if is_word_byte(byte) {
    4 // WordByte
  } else {
    0 // NonWordByte
  }
}

///|
let look_bits_start : UInt32 = @syntax.Look::Start.as_bit()

///|
let look_bits_end : UInt32 = @syntax.Look::End.as_bit()

///|
let look_bits_start_lf : UInt32 = @syntax.Look::StartLF.as_bit()

///|
let look_bits_end_lf : UInt32 = @syntax.Look::EndLF.as_bit()

///|
let look_bits_start_crlf : UInt32 = @syntax.Look::StartCRLF.as_bit()

///|
let look_bits_end_crlf : UInt32 = @syntax.Look::EndCRLF.as_bit()

///|
let look_bits_word : UInt32 = @syntax.Look::WordAscii.as_bit() |
  @syntax.Look::WordUnicode.as_bit()

///|
let look_bits_word_negate : UInt32 = @syntax.Look::WordAsciiNegate.as_bit() |
  @syntax.Look::WordUnicodeNegate.as_bit()

///|
let look_bits_word_start : UInt32 = @syntax.Look::WordStartAscii.as_bit() |
  @syntax.Look::WordStartUnicode.as_bit()

///|
let look_bits_word_end : UInt32 = @syntax.Look::WordEndAscii.as_bit() |
  @syntax.Look::WordEndUnicode.as_bit()

///|
let look_bits_word_start_half : UInt32 = @syntax.Look::WordStartHalfAscii.as_bit() |
  @syntax.Look::WordStartHalfUnicode.as_bit()

///|
let look_bits_word_end_half : UInt32 = @syntax.Look::WordEndHalfAscii.as_bit() |
  @syntax.Look::WordEndHalfUnicode.as_bit()

///|
/// A lazy DFA: a DFA whose states are computed on demand from an NFA.
pub struct LazyDFA {
  priv nfa : NFA
  priv match_all : Bool
  priv quit_non_ascii : Bool
  priv lineterm : Int32
  priv classes : FixedArray[Int32]
  priv stride : Int32
  priv mut trans : Array[Int32]
  priv mut states : Array[DState]
  priv mut map : Map[String, Int32]
  priv starts : FixedArray[Int32]
  priv stack : Array[Int32]
  priv set1 : SparseSet
  priv set2 : SparseSet
  priv state_limit : Int32
  priv mut clear_count : Int32
}

///|
/// Creates a new lazy DFA. When `match_all` is true, the DFA reports all
/// matches (used for reverse searches finding the start of a match).
pub fn LazyDFA::new(
  nfa : NFA,
  match_all~ : Bool = false,
  state_limit~ : Int32 = 10000,
) -> LazyDFA {
  let n = nfa.states.length()
  let dfa : LazyDFA = {
    nfa,
    match_all,
    quit_non_ascii: nfa.look_set_any.contains_word_unicode(),
    lineterm: '\n',
    classes: nfa.byte_classes,
    stride: nfa.byte_class_len + 1,
    trans: [],
    states: [],
    map: {},
    starts: FixedArray::make(12, -1),
    stack: [],
    set1: SparseSet::new(n),
    set2: SparseSet::new(n),
    state_limit,
    clear_count: 0,
  }
  dfa.reset()
  dfa
}

///|
fn LazyDFA::reset(self : LazyDFA) -> Unit {
  self.trans = []
  self.states = []
  self.map = {}
  for i in 0..<self.starts.length() {
    self.starts[i] = -1
  }
  // Dead state.
  let dead : DState = {
    nfa_ids: [],
    look_have: 0,
    look_need: 0,
    is_match: false,
    is_from_word: false,
    is_half_crlf: false,
  }
  ignore(self.add_state(dead))
  // Quit state (never interned).
  self.states.push(dead)
  for _ in 0..<self.stride {
    self.trans.push(quit_id * self.stride)
  }
  for i in 0..<self.stride {
    self.trans[i] = dead_id * self.stride
  }
}

///|
/// Transitions are stored as "tagged premultiplied" state IDs: the state's
/// index times the stride, with `MATCH_TAG` set for match states. Unknown
/// transitions are -1.
const MATCH_TAG : Int32 = 0x40000000

///|
const ID_MASK : Int32 = 0x3FFFFFFF

///|
fn LazyDFA::tag(self : LazyDFA, sid : Int32) -> Int32 {
  let pid = sid * self.stride
  if self.states[sid].is_match {
    pid | MATCH_TAG
  } else {
    pid
  }
}

///|
fn LazyDFA::add_state(self : LazyDFA, s : DState) -> Int32 {
  let key = s.key()
  match self.map.get(key) {
    Some(id) => id
    None => {
      let id = self.states.length()
      self.states.push(s)
      self.map[key] = id
      for _ in 0..<self.stride {
        self.trans.push(-1)
      }
      id
    }
  }
}

///|
fn LazyDFA::epsilon_closure(
  self : LazyDFA,
  start : Int32,
  look_have : UInt32,
  set : SparseSet,
) -> Unit {
  let states = self.nfa.states
  if !states[start].is_epsilon() {
    ignore(set.insert(start))
    return
  }
  let stack = self.stack
  stack.push(start)
  while stack.pop() is Some(id0) {
    let mut id = id0
    while true {
      if !set.insert(id) {
        break
      }
      match states[id] {
        ByteRange(_, _, _) | Sparse(_) | Fail | Match => break
        Look(look, next) => {
          if (look_have & look.as_bit()) == 0 {
            break
          }
          id = next
        }
        Union(alts) => {
          if alts.is_empty() {
            break
          }
          for i = alts.length() - 1; i >= 1; i = i - 1 {
            stack.push(alts[i])
          }
          id = alts[0]
        }
        BinaryUnion(a, b) => {
          stack.push(b)
          id = a
        }
        Capture(next~, ..) => id = next
      }
    }
  }
}

///|
/// Builds a DFA state from the NFA states in `set`.
fn LazyDFA::build_state(
  self : LazyDFA,
  set : SparseSet,
  look_have : UInt32,
  is_match : Bool,
  is_from_word : Bool,
  is_half_crlf : Bool,
) -> Int32 {
  let ids = []
  let mut need : UInt32 = 0
  let states = self.nfa.states
  for i in 0..<set.len {
    let id = set.dense[i]
    match states[id] {
      Capture(..) => ()
      Look(look, _) => {
        ids.push(id)
        need = need | look.as_bit()
      }
      _ => ids.push(id)
    }
  }
  let have = if need == 0 { 0U } else { look_have }
  self.add_state({
    nfa_ids: ids,
    look_have: have,
    look_need: need,
    is_match,
    is_from_word,
    is_half_crlf,
  })
}

///|
/// Computes the transition from state `sid` on `unit`, where `unit` is a
/// byte or 256 for the end-of-input sentinel.
fn LazyDFA::compute_next(self : LazyDFA, sid : Int32, unit : Int32) -> Int32 {
  if self.quit_non_ascii && unit >= 0x80 && unit < 256 {
    return quit_id
  }
  let state = self.states[sid]
  let nfa = self.nfa
  let rev = nfa.reverse
  let lineterm = self.lineterm
  let looks_any = nfa.look_set_any
  let set1 = self.set1
  let set2 = self.set2
  set1.clear()
  set2.clear()
  for id in state.nfa_ids {
    ignore(set1.insert(id))
  }
  let unit_word = unit < 256 && is_word_byte(unit)
  let mut cur = set1
  if state.look_need != 0 {
    let mut have = state.look_have
    if unit == '\r' {
      if !rev || !state.is_half_crlf {
        have = have | look_bits_end_crlf
      }
    } else if unit == '\n' {
      if rev || !state.is_half_crlf {
        have = have | look_bits_end_crlf
      }
    } else if unit == 256 {
      have = have | look_bits_end | look_bits_end_lf | look_bits_end_crlf
    }
    if unit == lineterm {
      have = have | look_bits_end_lf
    }
    if state.is_half_crlf && ((rev && unit != '\r') || (!rev && unit != '\n')) {
      have = have | look_bits_start_crlf
    }
    if state.is_from_word == unit_word {
      have = have | look_bits_word_negate
    } else {
      have = have | look_bits_word
    }
    if !unit_word {
      have = have | look_bits_word_end_half
    }
    if state.is_from_word && !unit_word {
      have = have | look_bits_word_end
    } else if !state.is_from_word && unit_word {
      have = have | look_bits_word_start
    }
    if (have & state.look_have.lnot() & state.look_need) != 0 {
      for i in 0..<set1.len {
        self.epsilon_closure(set1.dense[i], have, set2)
      }
      cur = set2
      set1.clear()
    }
  }
  // `cur` holds the current NFA states; the next states go into `out`.
  let out = if physical_equal(cur, set1) { set2 } else { set1 }
  out.clear()
  let mut new_have : UInt32 = 0
  if looks_any.contains_anchor_line() && unit == lineterm {
    new_have = new_have | look_bits_start_lf
  }
  if looks_any.contains_anchor_crlf() &&
    ((rev && unit == '\r') || (!rev && unit == '\n')) {
    new_have = new_have | look_bits_start_crlf
  }
  if looks_any.contains_word() && !unit_word {
    new_have = new_have | look_bits_word_start_half
  }
  let mut is_match = false
  let states = nfa.states
  for i in 0..<cur.len {
    let id = cur.dense[i]
    match states[id] {
      Match => {
        is_match = true
        if !self.match_all {
          break
        }
      }
      ByteRange(lo, hi, next) =>
        if unit >= lo && unit <= hi {
          self.epsilon_closure(next, new_have, out)
        }
      Sparse(ts) =>
        if unit < 256 {
          for t in ts {
            if unit < t.start {
              break
            }
            if unit <= t.end {
              self.epsilon_closure(t.next, new_have, out)
              break
            }
          }
        }
      _ => ()
    }
  }
  let mut from_word = false
  let mut half_crlf = false
  if out.len > 0 {
    if looks_any.contains_word() && unit_word {
      from_word = true
    }
    if looks_any.contains_anchor_crlf() &&
      ((rev && unit == '\n') || (!rev && unit == '\r')) {
      half_crlf = true
    }
  }
  self.build_state(out, new_have, is_match, from_word, half_crlf)
}

///|
/// Whether a search can't start after (or, in reverse, before) `byte`: like
/// upstream's quit set, a non-ASCII byte is a quit byte when Unicode word
/// boundaries are involved, so the caller must fall back to the PikeVM.
fn LazyDFA::start_quits(self : LazyDFA, byte : Int32) -> Bool {
  self.quit_non_ascii && byte >= 0x80
}

///|
/// Returns the start state for a search, given the byte preceding the
/// search (or -1 at the beginning of the haystack).
fn LazyDFA::start_state(
  self : LazyDFA,
  anchored : Bool,
  prev_byte : Int32,
) -> Int32 {
  let kind = start_kind(prev_byte, self.lineterm)
  let idx = (if anchored { 6 } else { 0 }) + kind
  if self.starts[idx] >= 0 {
    return self.starts[idx]
  }
  let nfa = self.nfa
  let rev = nfa.reverse
  let lookset = nfa.look_set_any
  let mut have : UInt32 = 0
  let mut from_word = false
  let mut half_crlf = false
  match kind {
    0 => if lookset.contains_word() { have = have | look_bits_word_start_half }
    4 => if lookset.contains_word() { from_word = true }
    1 => {
      if lookset.contains_anchor_haystack() {
        have = have | look_bits_start
      }
      if lookset.contains_anchor_line() {
        have = have | look_bits_start_lf | look_bits_start_crlf
      }
      if lookset.contains_word() {
        have = have | look_bits_word_start_half
      }
    }
    2 => {
      if rev {
        if lookset.contains_anchor_crlf() {
          half_crlf = true
        }
        if lookset.contains_anchor_line() {
          have = have | look_bits_start_lf
        }
      } else if lookset.contains_anchor_line() {
        have = have | look_bits_start_crlf
      }
      if lookset.contains_anchor_line() && self.lineterm == '\n' {
        have = have | look_bits_start_lf
      }
      if lookset.contains_word() {
        have = have | look_bits_word_start_half
      }
    }
    3 => {
      if lookset.contains_anchor_crlf() {
        if rev {
          have = have | look_bits_start_crlf
        } else {
          half_crlf = true
        }
      }
      if lookset.contains_anchor_line() && self.lineterm == '\r' {
        have = have | look_bits_start_lf
      }
      if lookset.contains_word() {
        have = have | look_bits_word_start_half
      }
    }
    _ => {
      if lookset.contains_anchor_line() {
        have = have | look_bits_start_lf
      }
      if lookset.contains_word() {
        if is_word_byte(self.lineterm) {
          from_word = true
        } else {
          have = have | look_bits_word_start_half
        }
      }
    }
  }
  let start = if anchored { nfa.start_anchored } else { nfa.start_unanchored }
  self.set1.clear()
  self.epsilon_closure(start, have, self.set1)
  let id = self.build_state(self.set1, have, false, from_word, half_crlf)
  self.starts[idx] = id
  id
}

///|
/// Returns the next state, computing it if necessary. Returns -1 if the
/// cache had to be cleared (and the search must be abandoned).
fn LazyDFA::next_state(self : LazyDFA, sid : Int32, unit : Int32) -> Int32 {
  let class = if unit == 256 { self.stride - 1 } else { self.classes[unit] }
  let idx = sid * self.stride + class
  let t = self.trans[idx]
  if t >= 0 {
    return (t & ID_MASK) / self.stride
  }
  if self.states.length() >= self.state_limit {
    self.clear_count += 1
    self.reset()
    return -1
  }
  let next = self.compute_next(sid, unit)
  self.trans[idx] = self.tag(next)
  next
}

///|
/// Searches forward in `hay[start:end]` for the end of the leftmost-first
/// match. Returns the end offset, `DFA_NO_MATCH` or `DFA_FAILED`.
pub fn LazyDFA::find_fwd(
  self : LazyDFA,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
  anchored : Bool,
  earliest : Bool,
  pre? : Prefilter,
) -> Int32 {
  let len = he
  let mut at = start
  let pre = if anchored { None } else { pre }
  if pre is Some(p) {
    let s = p.find_start(hay, at, end)
    if s < 0 {
      return DFA_NO_MATCH
    }
    at = s
  }
  let prev = if at > hs { hay[at - 1].to_int() } else { -1 }
  if self.start_quits(prev) {
    return DFA_FAILED
  }
  let mut sid = self.start_state(anchored, prev)
  let mut start_pid = sid * self.stride
  let mut mat = DFA_NO_MATCH
  let stride = self.stride
  let classes = self.classes
  let quit_pid = quit_id * stride
  let has_pre = pre is Some(_)
  let mut cur = sid * stride
  while at < end {
    let t = self.trans[cur + classes[hay[at].to_int()]]
    if t > quit_pid && t < MATCH_TAG {
      // Fast path: a known, non-special, non-matching state.
      cur = t
      at += 1
      if has_pre && cur == start_pid && mat < 0 {
        match pre {
          Some(p) =>
            match p.find_start(hay, at, end) {
              -1 => return DFA_NO_MATCH
              s =>
                if s > at {
                  at = s
                  let prev = if at > hs { hay[at - 1].to_int() } else { -1 }
                  if self.start_quits(prev) {
                    return DFA_FAILED
                  }
                  sid = self.start_state(false, prev)
                  start_pid = sid * stride
                  cur = start_pid
                }
            }
          None => ()
        }
      }
      continue
    }
    let b = hay[at].to_int()
    sid = if t >= 0 {
      (t & ID_MASK) / stride
    } else {
      self.next_state(cur / stride, b)
    }
    if sid <= quit_id {
      if sid == dead_id {
        return mat
      }
      return DFA_FAILED
    }
    cur = sid * stride
    if self.states[sid].is_match {
      mat = at
      if earliest {
        return mat
      }
    }
    at += 1
    if cur == start_pid && mat < 0 && pre is Some(p) {
      match p.find_start(hay, at, end) {
        -1 => return DFA_NO_MATCH
        s =>
          if s > at {
            at = s
            let prev = if at > hs { hay[at - 1].to_int() } else { -1 }
            if self.start_quits(prev) {
              return DFA_FAILED
            }
            sid = self.start_state(false, prev)
            start_pid = sid * stride
            cur = start_pid
          }
      }
    }
  }
  sid = cur / stride
  // End of input transition.
  if end < len {
    sid = self.next_state(sid, hay[end].to_int())
    if sid < 0 {
      return DFA_FAILED
    }
    if sid == quit_id {
      return if mat >= 0 { mat } else { DFA_FAILED }
    }
    if self.states[sid].is_match {
      mat = end
    }
  } else {
    sid = self.next_state(sid, 256)
    if sid < 0 {
      return DFA_FAILED
    }
    if self.states[sid].is_match {
      mat = len
    }
  }
  mat
}

///|
/// Searches backward in `hay[start:end]` from `end`, returning the start
/// offset of the match (or `DFA_NO_MATCH`/`DFA_FAILED`). This is used with a
/// reverse NFA to find the start of a match whose end is known.
pub fn LazyDFA::find_rev(
  self : LazyDFA,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  start : Int32,
  end : Int32,
  anchored : Bool,
  earliest : Bool,
) -> Int32 {
  let len = he
  let next_byte = if end < len { hay[end].to_int() } else { -1 }
  if self.start_quits(next_byte) {
    return DFA_FAILED
  }
  let mut sid = self.start_state(anchored, next_byte)
  let mut mat = DFA_NO_MATCH
  let mut at = end
  let stride = self.stride
  let classes = self.classes
  while at > start {
    at -= 1
    let b = hay[at].to_int()
    let t = self.trans[sid * stride + classes[b]]
    sid = if t >= 0 { (t & ID_MASK) / stride } else { self.next_state(sid, b) }
    if sid <= quit_id {
      if sid == dead_id {
        return mat
      }
      return DFA_FAILED
    }
    if self.states[sid].is_match {
      mat = at + 1
      if earliest {
        return mat
      }
    }
  }
  if start > hs {
    sid = self.next_state(sid, hay[start - 1].to_int())
    if sid < 0 {
      return DFA_FAILED
    }
    if sid == quit_id {
      return if mat >= 0 { mat } else { DFA_FAILED }
    }
    if self.states[sid].is_match {
      mat = start
    }
  } else {
    sid = self.next_state(sid, 256)
    if sid < 0 {
      return DFA_FAILED
    }
    if self.states[sid].is_match {
      mat = hs
    }
  }
  mat
}

///|
/// The number of states currently in the cache.
pub fn LazyDFA::state_count(self : LazyDFA) -> Int32 {
  self.states.length()
}

///|
/// The number of times the cache was cleared.
pub fn LazyDFA::clear_count(self : LazyDFA) -> Int32 {
  self.clear_count
}
