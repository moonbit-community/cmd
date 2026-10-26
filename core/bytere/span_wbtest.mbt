///|
test "compact spans agree with tagged matching at resumed starts and filtered endpoints" {
  let inputs = [""]
  let mut generation = [""]
  for _ in 0..<4 {
    let next : Array[String] = []
    for prefix in generation {
      for suffix in ["a", "b", " ", "!"] {
        next.push(prefix + suffix)
      }
    }
    inputs.append(next)
    generation = next
  }
  for
    source in [
      "", "a*", "a|aa", "(a|ab){0,2}", "((a?)*)b?", "(a|b)*a(a|b)*", "a.*b", "^a|b$",
      "a$|b", "[ab]+", "[^a]*", "a.|a", "(a|())*", "\\ba+\\b", "\\<a|b\\>", "a{1,3}",
      ".*", "[[:space:]]", "a?b?", "ab.*ba", "(ab)?", "(ab){1,2}", "(ab|ba)+", "a(ab)ba",
      "(ab|aab)!",
    ] {
    let pattern = compile(source, extended=true, grep_syntax=true)
    let matcher = pattern.record_matcher()
    for input in inputs {
      for start in 0..<=input.length() {
        for
          (whole, word) in [
            (false, false),
            (false, true),
            (true, false),
            (true, true),
          ] {
          for start_only in [false, true] {
            let expected = pattern.ordinary(
              input,
              start,
              whole,
              word,
              true,
              start_only~,
            )
            let actual = pattern.span_ordinary(
              input, start, whole, word, start_only,
            )
            assert_eq(
              actual.map(hit => (hit.start, hit.end)),
              expected.map(hit => (hit.start, hit.end)),
              msg=source + " on " + input + " at " + start.to_string(),
            )
            if start == 0 && !start_only {
              assert_eq(
                matcher.matches(bytes(input), whole~, word~),
                expected is Some(_),
                msg=source + " boolean on " + input,
              )
            }
          }
        }
      }
    }
  }
}

///|
test "record DFA handles every byte and case folding without decoding" {
  for
    source in [
      "[[:alpha:]]+", "[[:space:]]", "[^ab]+", "A+B", ".", "[\u0080-\u00ff]", "\u00ff",
    ] {
    for ignore_case in [false, true] {
      let pattern = compile(source, extended=true, ignore_case~)
      let matcher = pattern.record_matcher()
      for first in 0..<256 {
        let input = Bytes::from_array([first.to_byte(), b'b'])
        assert_eq(
          matcher.matches(input),
          pattern.find_span(text(input)) is Some(_),
        )
      }
    }
  }
}

///|
test "record DFA budget exhaustion falls back and keeps subsequent searches correct" {
  let pattern = compile("(a|b)*a(a|b){9}", extended=true)
  let matcher = pattern.record_matcher()
  assert_true(matcher.dfa is Some(_))
  for number in 0..<512 {
    let input = Bytes::makei(9, index => {
      if (number & (1 << index)) == 0 {
        b'a'
      } else {
        b'b'
      }
    })
    assert_eq(matcher.matches(input), pattern.find_span(text(input)) is Some(_))
  }
  assert_true(matcher.dfa is None)
  for input in [b"aaaaaaaaaa", b"bbbbbbbbbb", b"bbbabababababa", b""] {
    assert_eq(matcher.matches(input), pattern.find_span(text(input)) is Some(_))
  }
  for
    (source, extended) in [
      ("^a", true),
      ("a{300}", true),
      ("\\(a\\)\\1", false),
    ] {
    let pattern = compile(source, extended~)
    let matcher = pattern.record_matcher()
    assert_true(matcher.dfa is None)
    for input in [b"aa", b"ba", b""] {
      assert_eq(
        matcher.matches(input),
        pattern.find_span(text(input)) is Some(_),
      )
    }
  }
}
