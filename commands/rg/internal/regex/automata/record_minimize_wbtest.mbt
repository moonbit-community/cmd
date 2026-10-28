///|
// Compare the reachable product machine. Equal acceptance observations and
// closed transitions prove equivalence for every finite byte string, not just
// the sample haystacks used by endpoint and record-count regression tests.
fn assert_boolean_rows_equivalent(
  old : (FixedArray[Int32], FixedArray[Bool], Int32, Int32),
  revised : (FixedArray[Int32], FixedArray[Bool], Int32, Int32),
) -> Unit raise {
  let (old_table, old_eof, old_start, old_accept) = old
  let (new_table, new_eof, new_start, new_accept) = revised
  let pairs : Array[(Int32, Int32)] = [(old_start, new_start)]
  let visited = FixedArray::make(old_eof.length() * new_eof.length(), false)
  visited[old_start / 256 * new_eof.length() + new_start / 256] = true
  let mut index = 0
  while index < pairs.length() {
    let (before, after) = pairs[index]
    assert_eq(before == old_accept, after == new_accept)
    assert_eq(old_eof[before / 256], new_eof[after / 256])
    for byte in 0..<256 {
      let a = old_table[before + byte]
      let b = new_table[after + byte]
      let key = a / 256 * new_eof.length() + b / 256
      if !visited[key] {
        visited[key] = true
        pairs.push((a, b))
      }
    }
    index += 1
  }
}

///|
test "minimized plans preserve immediate and EOF acceptance on every transition" {
  for
    pattern in [
      "[0-9]{4}.*Q|ZZ", "[0-9]{4}.*gamma", "a+z|b+x", "\\p{Greek}+[0-9]+", "(?:ab){2,4}z|baz.*tail",
      "a.*?b", "a.*b", "[a-z&&0-9]", "[\\x00-\\x7f]+Q", "(?-u:[\\x80-\\xff]+)Q",
    ] {
    let nfa = compile_nfa(
      @syntax.parse(pattern, config={
        ..@syntax.ParseConfig::default(),
        utf8: false,
      }),
    )
    let plan = LazyDFA::new(nfa).record_boolean().unwrap()
    let old = plan.wide_rows()
    let alphabet : Array[Int32] = []
    let seen = FixedArray::make(plan.stride, false)
    for byte in 0..<256 {
      if !seen[plan.classes[byte]] {
        seen[plan.classes[byte]] = true
        alphabet.push(byte)
      }
    }
    let revised = minimize_boolean_rows(old.0, old.1, old.2, old.3, alphabet).unwrap()
    assert_boolean_rows_equivalent(old, revised)
    assert_eq(
      minimize_boolean_rows(old.0, old.1, old.2, old.3, alphabet, budget=0),
      None,
    )
    assert_eq(
      minimize_boolean_rows(old.0, old.1, old.2, old.3, alphabet, budget=1),
      None,
    )
  }
}

///|
test "minimized repetition no longer exits on equivalent digit histories" {
  let nfa = compile_nfa(@syntax.parse("[0-9]{4}.*Q|ZZ"))
  let plan = LazyDFA::new(nfa).record_boolean().unwrap().wide_plan()
  let mut state = plan.start
  for byte in b"0123456789 alpha beta gamma " {
    state = plan.transitions[state + byte.to_int()]
  }
  guard plan.accelerators[state / 256] is Some(ByteSet(set)) else {
    abort("missing byte-set accelerator")
  }
  for byte in b"0123456789" {
    assert_false(set.contains(byte))
  }
  assert_true(set.contains(b'Q'))
  assert_true(set.contains(b'Z'))
}

///|
test "a deep refinement chain declines at its iteration budget" {
  let states = 40
  let accept = (states - 1) * 256
  let table = FixedArray::makei(states * 256, i => {
    (i / 256 + 1).min(states - 1) * 256
  })
  let eof = FixedArray::makei(states, i => i == states - 1)
  assert_eq(minimize_boolean_rows(table, eof, 0, accept, [0]), None)
  for i in 0..<(states * 256) {
    assert_eq(table[i], (i / 256 + 1).min(states - 1) * 256)
  }
}

///|
test "a broad exit set still accelerates a homogeneous long haystack" {
  let nfa = compile_nfa(@syntax.parse("[ab]{32}Q"))
  let compact = LazyDFA::new(nfa).record_boolean().unwrap()
  let plan = compact.wide_plan()
  let mut state = plan.start
  for byte in b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" {
    state = plan.transitions[state + byte.to_int()]
  }
  guard plan.accelerators[state / 256] is Some(ByteSet(set)) else {
    abort("missing broad exit-set accelerator")
  }
  assert_false(set.contains(b'a'))
  assert_false(set.contains(b'b'))
  for byte in 0..<256 {
    assert_eq(
      set.contains(byte.to_byte()),
      plan.transitions[state + byte] != state,
    )
  }
  for suffix in [b"", b"Q", b"cQ", b"bQ", b"\xffQ"] {
    let hay = (Bytes::make(1048576, b'a') + suffix).to_fixedarray()
    assert_eq(
      compact.count_long_lines(hay, 0, hay.length(), b'\n'),
      compact.count_lines(hay, 0, hay.length(), b'\n'),
    )
  }
}
