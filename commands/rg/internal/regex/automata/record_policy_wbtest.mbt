///|
test "boolean NFA budget includes the limit and declines one extra state" {
  let base = compile_nfa(@syntax.parse("a"))
  for
    size in [
      boolean_nfa_state_limit - 1,
      boolean_nfa_state_limit,
      boolean_nfa_state_limit + 1,
    ] {
    // Unreachable fail states change construction size without changing language.
    let nfa = {
      ..base,
      states: Array::makei(size, i => {
        if i < base.states.length() {
          base.states[i]
        } else {
          Fail
        }
      }),
    }
    let plan = LazyDFA::new(nfa).record_boolean()
    assert_eq(plan is Some(_), size <= boolean_nfa_state_limit)
  }
}

///|
test "refinement work budget declines below the exact fixed point cost" {
  let table = FixedArray::make(256, 0)
  let eof = FixedArray::make(1, true)
  // Two refinement rounds, each with one state and three signature components.
  for budget in [5, 6, 7] {
    let result = minimize_boolean_rows(table, eof, 0, 0, [0], budget~)
    assert_eq(result is Some(_), budget >= 6)
    if result is Some(result) {
      assert_boolean_rows_equivalent((table, eof, 0, 0), result)
    }
  }
}
