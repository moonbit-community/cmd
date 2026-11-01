///|
test "real successful scans amortize pressure before a later unproductive window" {
  let dfa = LazyDFA::new(compile_nfa(@syntax.parse("abcdef")), state_limit=5)
  let pressure = b"abcdef".to_fixedarray()
  for _ in 0..<2 {
    assert_eq(dfa.find_fwd(pressure, 0, 6, 0, 6, false, false), DFA_FAILED)
  }
  let productive = FixedArray::make(4096, b'a')
  for _ in 0..<3 {
    assert_eq(
      dfa.find_fwd(productive, 0, 4096, 0, 4096, false, false),
      DFA_NO_MATCH,
    )
  }
  guard dfa.health is Measuring(before) else {
    abort("productive scan retired")
  }
  assert_eq(before.clears, 2)
  assert_true(before.searched >= 12288L)
  assert_eq(dfa.find_fwd(pressure, 0, 6, 0, 6, false, false), DFA_FAILED)
  guard dfa.health is Measuring(restarted) else {
    abort("productive window retired")
  }
  assert_eq(restarted.clears, 0)
  assert_eq(restarted.searched, 0L)
  for attempt in 1..<=3 {
    assert_eq(dfa.find_fwd(pressure, 0, 6, 0, 6, false, false), DFA_FAILED)
    assert_eq(dfa.health is Retired, attempt == 3)
  }
}

///|
test "DFA cache capacity preserves known rows exactly at the construction limit" {
  let nfa = compile_nfa(@syntax.parse("abcdef"))
  let hay = b"abcdef".to_fixedarray()
  let reference = LazyDFA::new(nfa)
  assert_eq(reference.find_fwd(hay, 0, 6, 0, 6, false, false), 6)
  let required = reference.states.length()
  for limit in [required - 1, required, required + 1] {
    let dfa = LazyDFA::new(nfa, state_limit=limit)
    assert_eq(
      dfa.find_fwd(hay, 0, 6, 0, 6, false, false),
      if limit < required {
        DFA_FAILED
      } else {
        6
      },
    )
    if limit >= required {
      let rows = dfa.trans.copy()
      assert_eq(dfa.find_fwd(hay, 0, 6, 0, 6, false, false), 6)
      assert_eq(dfa.trans, rows)
      guard dfa.health is Measuring(work) else { abort("known rows retired") }
      assert_eq(work.clears, 0)
    }
  }
}

///|
test "repeated cache pressure retires an unproductive DFA without retrying rows" {
  for reverse in [false, true] {
    let nfa = compile_nfa(@syntax.parse("abcdef"), config={
      ..NFAConfig::default(),
      reverse,
    })
    let dfa = LazyDFA::new(nfa, match_all=reverse, state_limit=5)
    let hay = b"abcdef".to_fixedarray()
    for attempt in 1..<=dfa_pressure_clear_limit {
      let result = if reverse {
        dfa.find_rev(hay, 0, 6, 0, 6, true, false)
      } else {
        dfa.find_fwd(hay, 0, 6, 0, 6, false, false)
      }
      assert_eq(result, DFA_FAILED)
      assert_eq(dfa.health is Retired, attempt == dfa_pressure_clear_limit)
      if dfa.health is Measuring(work) {
        assert_eq(work.clears, attempt)
        // The synthetic quit row is not constructed through the interner.
        assert_eq(work.constructed, 1L + attempt.to_int64() * 4L)
        assert_true(work.searched > 0L)
      }
    }
    let rows = dfa.trans.copy()
    for _ in 0..<4 {
      assert_eq(
        if reverse {
          dfa.find_rev(hay, 0, 6, 0, 6, true, false)
        } else {
          dfa.find_fwd(hay, 0, 6, 0, 6, false, false)
        },
        DFA_FAILED,
      )
      assert_eq(dfa.trans, rows)
    }
  }
}

///|
test "Unicode quits never retire later ASCII searches" {
  let dfa = LazyDFA::new(compile_nfa(@syntax.parse("\\bword\\b")))
  let unicode = b"\xc3\xa9word".to_fixedarray()
  for _ in 0..<8 {
    assert_eq(
      dfa.find_fwd(
        unicode,
        0,
        unicode.length(),
        2,
        unicode.length(),
        false,
        false,
      ),
      DFA_FAILED,
    )
    guard dfa.health is Measuring(work) else {
      abort("Unicode quit retired DFA")
    }
    assert_eq(work.clears, 0)
  }
  let ascii = b" word ".to_fixedarray()
  assert_eq(dfa.find_fwd(ascii, 0, 6, 0, 6, false, false), 5)
}

///|
test "productive cache windows restart accounting at the exact cost boundary" {
  for bytes in [29, 30, 31] {
    let dfa = LazyDFA::new(compile_nfa(@syntax.parse("a")))
    dfa.health = Measuring({
      clears: dfa_pressure_clear_limit,
      constructed: 3L,
      searched: 0L,
    })
    dfa.record_search(bytes)
    assert_eq(dfa.health is Retired, bytes < 30)
    if dfa.health is Measuring(work) {
      assert_eq(work.clears, 0)
      assert_eq(work.constructed, 0L)
      assert_eq(work.searched, 0L)
    }
  }
}
