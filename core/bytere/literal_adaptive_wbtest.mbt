///|
test "adaptive construction is lazy cached and bounded" {
  for length in [32, 256] {
    let patterns = Array::makei(16, number => {
      Bytes::makei(length, index => {
        if index == 0 {
          (98 + number).to_byte()
        } else {
          b'a'
        }
      })
    })
    let set = LiteralSet::new(patterns).unwrap()
    assert_true(!set.automaton_attempted)
    assert_true(!set.matches(Bytes::make(8192, b'Z')))
    assert_true(!set.automaton_attempted)
    assert_true(!set.matches(Bytes::make(8192, b'a')))
    assert_true(set.automaton_attempted)
    assert_eq(set.automaton is Some(_), length == 32)
    // A cached automaton does not replace the sparse-input shift plan.
    assert_true(set.shift is Some(_))
    assert_true(!set.matches(Bytes::make(8192, b'Z')))
    assert_true(set.matches(patterns[0]))
    assert_true(!set.matches(Bytes::make(8192, b'a')))
    assert_eq(set.automaton is Some(_), length == 32)
  }
}
