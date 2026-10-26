///|
test "literal sets preserve leftmost longest and resumed view offsets" {
  let patterns = [b"a", b"ab", b"aba", b"ba", b"bab", b"\xffa"]
  let set = @bytere.LiteralSet::new(patterns).unwrap()
  let inputs = [b"", b"ababa", b"\xffab", b"xxxbababa", b"nothing"]
  for input in inputs {
    let storage = b"prefix" + input + b"suffix"
    let view = storage[6:6 + input.length()]
    for start in 0..<=input.length() {
      let mut expected : (Int32, Int32)? = None
      for pattern in patterns {
        if view[start:].find(pattern) is Some(relative) {
          let left = start + relative
          let right = left + pattern.length()
          match expected {
            Some((old_left, old_right)) =>
              if left < old_left || (left == old_left && right > old_right) {
                expected = Some((left, right))
              }
            None => expected = Some((left, right))
          }
        }
      }
      assert_eq(set.find_span(view, start~), expected)
      if start == 0 {
        assert_eq(set.matches(view), expected is Some(_))
      }
    }
  }
  assert_true(set.contains_byte(b'\xff'))
  assert_true(!set.contains_byte(b'\x00'))
  assert_true(@bytere.LiteralSet::new([b""]) is None)
  assert_true(@bytere.LiteralSet::new([Bytes::make(4097, b'a')]) is None)
}

///|
test "self loop skips preserve endpoints on long and offset byte records" {
  for
    source in [
      "a.*z|b", "a.*z|a", "a.*", ".*", "a[^z]*z", "a.*z.*z", "a.*z|a.*y",
    ] {
    let pattern = @bytere.compile(source, extended=true)
    let matcher = pattern.record_matcher()
    for tail in [b"", b"z", b"zyz", b"\xffz", b"b"] {
      let storage = b"prefix" +
        b"a" +
        Bytes::make(8192, b'x') +
        tail +
        b"suffix"
      let value = storage[6:storage.length() - 6]
      let search = matcher.search_bytes(value)
      for start in [0, 1, 17, 1024, value.length()] {
        assert_eq(
          search.find_span(start~),
          pattern.find_span(@bytere.text(value), start~),
        )
      }
    }
  }
}

///|
test "two-byte shifts agree with independent literal searches at every start" {
  let patterns = [
    b"aba", b"bab", b"ababa", b"babbab", b"\x01\x00a", b"\x00\x10a",
  ]
  let set = @bytere.LiteralSet::new(patterns).unwrap()
  let inputs = [b"", b"\x00\x10a\x01\x00a", b"\x01\x00b\x00\x10b"]
  for number in 0..<256 {
    inputs.push(
      Bytes::makei(8, index => {
        if (number & (1 << index)) == 0 {
          b'a'
        } else {
          b'b'
        }
      }),
    )
  }
  for input in inputs {
    for start in 0..<=input.length() {
      let mut best : (Int32, Int32)? = None
      for pattern in patterns {
        if input[start:].find(pattern) is Some(offset) {
          let candidate = (start + offset, start + offset + pattern.length())
          match best {
            Some(old) =>
              if candidate.0 < old.0 ||
                (candidate.0 == old.0 && candidate.1 > old.1) {
                best = Some(candidate)
              }
            None => best = Some(candidate)
          }
        }
      }
      assert_eq(set.find_span(input, start~), best)
    }
  }
}

///|
test "suffix certificates stay within one record and support decreasing starts" {
  let pattern = @bytere.compile("a|a.*z", extended=true)
  let matcher = pattern.record_matcher()
  let miss = matcher.search_bytes(Bytes::make(8192, b'a'))
  let hit = matcher.search_bytes(Bytes::make(8192, b'a') + b"z")
  for start in [0, 64, 4096, 1, 8191, 0] {
    assert_eq(miss.find_span(start~), Some((start, start + 1)))
    assert_eq(hit.find_span(start~), Some((start, 8193)))
  }
}

///|
test "literal existence scans preserve record order and budget fallbacks" {
  // Earliest endpoint is sufficient for counting records, but not for spans.
  let set = @bytere.LiteralSet::new([b"abcdef", b"bc", b"x", b"z"]).unwrap()
  assert_eq(set.find_any(b"abcdef\nx"), Some((1, 3)))
  assert_eq(set.find_span(b"abcdef\nx"), Some((0, 6)))
  assert_eq(set.find_any(b"abcdef\nx", start=7), Some((7, 8)))
  assert_eq(set.find_any(b"x", start=-1), None)
  assert_eq(set.find_any(b"x", start=2), None)
  let shifted = @bytere.LiteralSet::new([b"abcdef", b"abc", b"xyz"]).unwrap()
  assert_eq(shifted.find_span(b"abcdef\nxyz"), Some((0, 6)))
  assert_eq(shifted.find_any(b"abcdef\nxyz", start=7), Some((7, 10)))
  assert_true(@bytere.LiteralSet::new([]) is None)
  assert_true(@bytere.LiteralSet::new([b"x", Bytes::make(1024, b'a')]) is None)
}

///|
test "short literal failure transitions agree with independent searches" {
  let patterns = [b"b", b"ab", b"baa", b"aba", b"aabaa", b"babbab"]
  let set = @bytere.LiteralSet::new(patterns).unwrap()
  for number in 0..<256 {
    let input = Bytes::makei(8, index => {
      if (number & (1 << index)) == 0 {
        b'a'
      } else {
        b'b'
      }
    })
    for start in 0..<=input.length() {
      let mut best : (Int32, Int32)? = None
      for pattern in patterns {
        if input[start:].find(pattern) is Some(offset) {
          let candidate = (start + offset, start + offset + pattern.length())
          match best {
            Some(old) =>
              if candidate.0 < old.0 ||
                (candidate.0 == old.0 && candidate.1 > old.1) {
                best = Some(candidate)
              }
            None => best = Some(candidate)
          }
        }
      }
      assert_eq(set.find_span(input, start~), best)
      let any = set.find_any(input, start~)
      assert_eq(any is Some(_), best is Some(_))
      if any is Some((left, right)) {
        assert_true(left >= start)
        assert_true(
          patterns.iter().any(pattern => input[left:right] == pattern[:]),
        )
      }
    }
  }
}
