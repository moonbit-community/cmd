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
            if !start_only {
              let storage = b"prefix" + bytes(input) + b"suffix"
              assert_eq(
                matcher
                .search_bytes(storage[6:6 + input.length()], whole~, word~)
                .find_span(start~),
                expected.map(hit => (hit.start, hit.end)),
                msg=source + " byte span on " + input,
              )
              assert_eq(
                matcher.find_span(input, start~, whole~, word~),
                expected.map(hit => (hit.start, hit.end)),
                msg=source + " cached span on " + input,
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
  assert_true(!matcher.matches(b""))
  assert_true(matcher.dfa is Ready(_))
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
  assert_true(matcher.dfa is (Uninitialized | Disabled))
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
    assert_true(matcher.dfa is (Uninitialized | Disabled))
    for input in [b"aa", b"ba", b""] {
      assert_eq(
        matcher.matches(input),
        pattern.find_span(text(input)) is Some(_),
      )
    }
  }
}

///|
test "endpoint caches fall back on exhaustion and keep old searches valid" {
  let pattern = compile("(a|b)*a(a|b){9}", extended=true)
  let matcher = pattern.record_matcher()
  let retained = matcher.search_bytes(b"aaaaaaaaaa")
  assert_eq(retained.find_span(), Some((0, 10)))
  assert_true(matcher.span_dfa is Ready(_))
  for number in 0..<2048 {
    let input = Bytes::makei(12, index => {
      if (number & (1 << index)) == 0 {
        b'a'
      } else {
        b'b'
      }
    })
    let search = matcher.search_bytes(input)
    for start in [0, 1, 3, 12] {
      assert_eq(
        search.find_span(start~),
        pattern.find_span(text(input), start~),
      )
    }
  }
  assert_true(matcher.span_dfa is (Uninitialized | Disabled))
  assert_eq(retained.find_span(), Some((0, 10)))
}

///|
test "multiple fallback searches share one record conversion" {
  let searches = search_bytes(
    [compile("^a").record_matcher(), compile("\\(a\\)\\1").record_matcher()],
    b"aa",
  )
  assert_true(searches[1].input.decoded is None)
  assert_eq(searches[1].find_span(), Some((0, 2)))
  assert_true(searches[0].input.decoded is Some(_))
  assert_eq(searches[0].find_span(), Some((0, 1)))
}
