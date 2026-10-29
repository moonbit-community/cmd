///|
test "reverse cache pressure falls back over the original full span" {
  let regex = Regex::new("[a-z]+[0-9]+")
  guard regex.rev is Pending(nfa) else {
    abort("unexpected reverse preparation")
  }
  regex.rev = Prepared(
    @automata.LazyDFA::new(nfa, match_all=true, state_limit=3),
  )
  let hay = b"!abc123 tail9!".to_fixedarray()
  for _ in 0..<5 {
    assert_eq(
      regex.find_at(hay, 0, hay.length(), 0, hay.length()),
      Some((1, 7)),
    )
    assert_eq(
      regex.find_at(hay, 0, hay.length(), 7, hay.length()),
      Some((8, 13)),
    )
  }
  assert_true(regex.pikevm is Prepared(_))
}

///|
test "half and boolean searches prepare neither reverse nor capture storage" {
  let regex = Regex::new("(?P<digits>[0-9]+).*Q")
  let hay = b"12 alpha Q".to_fixedarray()
  assert_eq(regex.group_index("digits"), Some(1))
  assert_eq(regex.captures_len(), 2)
  assert_true(regex.pikevm is Pending(_))
  assert_true(regex.rev is Pending(_))
  assert_eq(regex.search_half(hay, 0, 10, 0, 10), Some(10))
  assert_eq(regex.count_boolean_lines(hay, 0, 10, b'\n'), Some(1L))
  assert_true(regex.pikevm is Pending(_))
  assert_true(regex.rev is Pending(_))
  let slots = FixedArray::make(4, -1)
  assert_true(regex.captures_at(hay, 0, 10, 0, 10, slots))
  assert_eq(slots, [0, 10, 0, 2])
  assert_true(regex.pikevm is Prepared(_))
  assert_true(regex.rev is Prepared(_))
  let vm = regex.pikevm_engine()
  assert_true(physical_equal(vm, regex.pikevm_engine()))
}

///|
test "deferred fallback preserves low-budget spans earliest endpoints and Unicode" {
  for pattern in ["(?P<x>a+b)c+", "\\bword\\b", "[a-z]{6}Q"] {
    let hir = @syntax.parse(pattern)
    let limited = Regex::from_hir(hir, config={
      nfa_size_limit: None,
      dfa_state_limit: 3,
    })
    let ordinary = Regex::from_hir(hir)
    for hay in [b"xxaaabcccQ", b"\xc3\xa9 word word\xc3\xa9", b"xxabcdefQtail"] {
      let hay = hay.to_fixedarray()
      for _ in 0..<5 {
        for start in [0, 2] {
          for earliest in [false, true] {
            assert_eq(
              limited.search_half(
                hay,
                0,
                hay.length(),
                start,
                hay.length(),
                earliest~,
              ),
              ordinary.search_half(
                hay,
                0,
                hay.length(),
                start,
                hay.length(),
                earliest~,
              ),
            )
          }
          assert_eq(
            limited.find_at(hay, 0, hay.length(), start, hay.length()),
            ordinary.find_at(hay, 0, hay.length(), start, hay.length()),
          )
          let a = FixedArray::make(2 * limited.captures_len(), -1)
          let b = FixedArray::make(a.length(), -1)
          assert_eq(
            limited.captures_at(hay, 0, hay.length(), start, hay.length(), a),
            ordinary.captures_at(hay, 0, hay.length(), start, hay.length(), b),
          )
          assert_eq(a, b)
        }
      }
    }
  }
}

///|
test "literal engines defer storage without removing extended capture slots" {
  let regex = Regex::new("literal")
  let hay = b"literal".to_fixedarray()
  assert_eq(regex.find_at(hay, 0, 7, 0, 7), Some((0, 7)))
  assert_true(regex.pikevm is Pending(_))
  assert_true(regex.rev is Pending(_))
  let slots = FixedArray::make(4, -1)
  assert_true(regex.captures_at(hay, 0, 7, 0, 7, slots))
  assert_eq(slots, [0, 7, -1, -1])
  assert_true(regex.pikevm is Prepared(_))
}
