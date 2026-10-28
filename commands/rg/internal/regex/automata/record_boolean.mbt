///|
// Immutable count-only plan. Resolve reachable transitions within fixed
// construction budgets; a declined plan leaves the existing engine intact.
pub struct RecordBoolean {
  priv classes : FixedArray[Int32]
  priv transitions : FixedArray[Int32]
  priv stride : Int32
  priv start : Int32
  priv mut wide : WideBoolean?
}

///|
pub fn LazyDFA::record_boolean(self : LazyDFA) -> RecordBoolean? {
  if !self.nfa.look_set_any.is_empty() || self.nfa.states.length() > 512 {
    return None
  }
  let dfa = LazyDFA::new(self.nfa, state_limit=257)
  let start = dfa.start_state(false, -1)
  let empty = dfa.next_state(start, 256)
  if empty < 0 || dfa.states[empty].is_match {
    return None
  }
  let representatives = FixedArray::make(dfa.stride, -1)
  for byte in 0..<256 {
    representatives[dfa.classes[byte]] = byte
  }
  representatives[dfa.stride - 1] = 256
  let mut sid = 2
  while sid < dfa.states.length() {
    if dfa.states.length() > 256 || dfa.states.length() * dfa.stride > 65536 {
      return None
    }
    if !dfa.states[sid].is_match {
      for unit in representatives {
        if unit >= 0 {
          let next = dfa.next_state(sid, unit)
          if next < 0 || next == quit_id || dfa.states.length() > 256 {
            return None
          }
        }
      }
    }
    sid += 1
  }
  Some({
    classes: dfa.classes,
    transitions: FixedArray::makei(dfa.trans.length(), i => dfa.trans[i]),
    stride: dfa.stride,
    start: start * dfa.stride,
    wide: None,
  })
}
