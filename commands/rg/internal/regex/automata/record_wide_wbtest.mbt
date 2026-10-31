///|
test "Unicode dot self loops retain every byte that changes state" {
  let nfa = compile_nfa(@syntax.parse("[0-9]{4}.*Q|ZZ"))
  let compact = LazyDFA::new(nfa).record_boolean().unwrap()
  let plan = compact.wide_plan()
  let mut state = plan.start
  for byte in b"0001xxxxxxxx" {
    state = plan.transitions[state + byte.to_int()]
  }
  assert_true(state != plan.accept)
  guard plan.accelerators[state / 256] is Some(ByteSet(set)) else {
    abort("expected a Unicode-aware byte-set accelerator")
  }
  for byte in 0..<256 {
    assert_eq(
      set.contains(byte.to_byte()),
      plan.transitions[state + byte] != state,
    )
  }
  assert_false(set.contains(b'x'))
  assert_true(set.contains(b'Q'))
}
