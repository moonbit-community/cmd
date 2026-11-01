///|
test "anchored linear plans decline branching and position-sensitive syntax" {
  for
    source in ["^.{8}alpha", "^a", "^a$", "^(ab){2}$", "^[ab][^a].$", "^$", "^"] {
    assert_true(compile(source, extended=true).is_anchored_linear(), msg=source)
  }
  for source in ["a", "a$", "^a*", "^a?", "^a|b", "^a\\b", "^(a)\\1", "^.{300}"] {
    assert_true(
      !compile(source, extended=true).is_anchored_linear(),
      msg=source,
    )
  }
  assert_true(!compile("^a", emacs=true).is_anchored_linear())
}

///|
test "anchored byte predicates agree with the span engine across all short records" {
  let alphabet = [b'a', b'b', b'\n', b'\x00', b'\xff']
  let inputs : Array[Bytes] = [b""]
  let mut frontier : Array[Bytes] = [b""]
  for _ in 0..<4 {
    let next : Array[Bytes] = []
    for prefix in frontier {
      for byte in alphabet {
        let data = prefix + Bytes::from_array([byte])
        next.push(data)
        inputs.push(data)
      }
    }
    frontier = next
  }
  for
    source in [
      "^", "^$", "^a", "^a$", "^(ab)", "^.{2}", "^.{2}$", "^[ab][^a].$", "^(a){2}",
      "^((ab))$", "^a?", "^a|b", "^a\\b",
    ] {
    for ignore_case in [false, true] {
      let pattern = compile(source, extended=true, ignore_case~)
      let matcher = pattern.record_matcher()
      for input in inputs {
        let text = text(input[:])
        for (whole, word) in [(false, false), (true, false), (false, true)] {
          assert_eq(
            matcher.matches(input[:], whole~, word~),
            pattern.find_span(text, whole~, word~) is Some(_),
            msg=source,
          )
        }
      }
    }
  }
}
