///|
test "resolved state and transition cell budgets enforce exact boundaries" {
  let single = LazyDFA::new(compile_nfa(@syntax.parse("a")))
    .record_boolean()
    .unwrap()
  let extra_states = single.transitions.length() / single.stride - 1
  for
    states in [
      boolean_dfa_state_limit - 1,
      boolean_dfa_state_limit,
      boolean_dfa_state_limit + 1,
    ] {
    let nfa = compile_nfa(@syntax.parse("a".repeat(states - extra_states)))
    let plan = LazyDFA::new(nfa).record_boolean()
    assert_eq(plan is Some(_), states <= boolean_dfa_state_limit)
    if plan is Some(plan) {
      assert_eq(plan.transitions.length() / plan.stride, states)
    }
  }
  let base = compile_nfa(
    @syntax.parse("a".repeat(boolean_dfa_state_limit - extra_states)),
  )
  // Refine equivalent byte classes without changing the language: 255 byte
  // classes plus EOF make exactly 256 cells in each of 256 resolved rows.
  let nfa = {
    ..base,
    byte_classes: FixedArray::makei(256, i => i.min(254)),
    byte_class_len: 255,
  }
  for
    cells in [
      boolean_table_entry_limit - 1,
      boolean_table_entry_limit,
      boolean_table_entry_limit + 1,
    ] {
    let plan = LazyDFA::new(nfa).record_boolean_with_table_limit(cells)
    assert_eq(plan is Some(_), cells >= boolean_table_entry_limit)
    if plan is Some(plan) {
      assert_eq(plan.transitions.length(), boolean_table_entry_limit)
    }
  }
}

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
