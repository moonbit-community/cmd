///|
test "resolved state and transition cell budgets enforce exact boundaries" {
  let single = LazyDfa::new(compile_nfa(@syntax.parse("a")))
    .record_boolean()
    .unwrap()
  let extra_states = single.transitions.length() / single.stride - 1
  for
    states in [
      BOOLEAN_DFA_STATE_LIMIT - 1,
      BOOLEAN_DFA_STATE_LIMIT,
      BOOLEAN_DFA_STATE_LIMIT + 1,
    ] {
    let nfa = compile_nfa(@syntax.parse("a".repeat(states - extra_states)))
    let plan = LazyDfa::new(nfa).record_boolean()
    assert_eq(plan is Some(_), states <= BOOLEAN_DFA_STATE_LIMIT)
    if plan is Some(plan) {
      assert_eq(plan.transitions.length() / plan.stride, states)
    }
  }
  let base = compile_nfa(
    @syntax.parse("a".repeat(BOOLEAN_DFA_STATE_LIMIT - extra_states)),
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
      BOOLEAN_TABLE_ENTRY_LIMIT - 1,
      BOOLEAN_TABLE_ENTRY_LIMIT,
      BOOLEAN_TABLE_ENTRY_LIMIT + 1,
    ] {
    let plan = LazyDfa::new(nfa).record_boolean_with_table_limit(cells)
    assert_eq(plan is Some(_), cells >= BOOLEAN_TABLE_ENTRY_LIMIT)
    if plan is Some(plan) {
      assert_eq(plan.transitions.length(), BOOLEAN_TABLE_ENTRY_LIMIT)
    }
  }
}

///|
test "boolean NFA budget includes the limit and declines one extra state" {
  let base = compile_nfa(@syntax.parse("a"))
  for
    size in [
      BOOLEAN_NFA_STATE_LIMIT - 1,
      BOOLEAN_NFA_STATE_LIMIT,
      BOOLEAN_NFA_STATE_LIMIT + 1,
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
    let plan = LazyDfa::new(nfa).record_boolean()
    assert_eq(plan is Some(_), size <= BOOLEAN_NFA_STATE_LIMIT)
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
