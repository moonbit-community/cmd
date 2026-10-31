///|
test "literal byte and automaton state budgets include their exact boundaries" {
  for
    size in [
      literal_set_byte_limit - 1,
      literal_set_byte_limit,
      literal_set_byte_limit + 1,
    ] {
    let pattern = Bytes::make(size, b'a')
    let set = LiteralSet::new([pattern])
    assert_eq(set is Some(_), size <= literal_set_byte_limit)
    if set is Some(set) {
      assert_true(set.matches(pattern))
    }
  }
  let classes = FixedArray::makei(256, i => if i == 97 { 1 } else { 0 })
  for
    states in [
      literal_automaton_state_limit - 1,
      literal_automaton_state_limit,
      literal_automaton_state_limit + 1,
    ] {
    let pattern = Bytes::make(states - 1, b'a')
    let plan = LiteralAutomaton::new([pattern], classes)
    assert_eq(plan is Some(_), states <= literal_automaton_state_limit)
    if plan is Some(plan) {
      assert_eq(plan.search(pattern, 0, false), Some((0, states - 1)))
    }
  }
}

///|
test "record NFA construction includes the exact state budget" {
  for states in [255, 256, 257] {
    let pattern = compile("a{" + (states - 1).to_string() + "}", extended=true)
    assert_eq(pattern.program.length(), states)
    let dfa = RecordDfa::new(pattern)
    assert_eq(dfa is Some(_), states <= record_nfa_state_limit)
    let hit = Bytes::make(states - 1, b'a')
    assert_true(pattern.record_matcher().matches(hit))
    assert_true(!pattern.record_matcher().matches(hit[:hit.length() - 1]))
  }
}

///|
test "record DFA admits 255 and 256 states and rejects a 257th without losing cached rows" {
  let pattern = compile("(a|b)*a(a|b){9}", extended=true)
  for target in [255, 256, 257] {
    guard RecordDfa::new(pattern) is Some(dfa) else {
      fail("expected record DFA")
    }
    let width = dfa.representatives.length()
    let mut row = 0
    let mut exhausted = false
    while row < dfa.states.length() &&
          dfa.states.length() < target &&
          !exhausted {
      for class in 0..<width {
        if dfa.transition(row * width, class) == -3 {
          exhausted = true
          break
        }
        if dfa.states.length() == target {
          break
        }
      }
      row += 1
    }
    assert_eq(dfa.states.length(), target.min(record_dfa_state_limit))
    assert_eq(exhausted, target > record_dfa_state_limit)
    // The first row was fully cached before saturation and remains reusable.
    assert_true(dfa.transition(0, dfa.classes[97]) >= 0)
    assert_eq(dfa.matches(b""), Some(false))
  }
}
