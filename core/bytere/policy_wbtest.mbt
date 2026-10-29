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
