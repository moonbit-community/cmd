///|
fn collision_patterns(marker : Int32) -> Array[Bytes] {
  Array::makei(16, number => {
    Bytes::makei(32, index => {
      if index == marker {
        (98 + number).to_byte()
      } else {
        b'a'
      }
    })
  })
}

///|
fn literal_oracle(
  patterns : Array[Bytes],
  value : BytesView,
  start : Int32,
) -> (Int32, Int32)? {
  if start < 0 || start >= value.length() {
    return None
  }
  let mut best : (Int32, Int32)? = None
  for pattern in patterns {
    if value[start:].find(pattern) is Some(relative) {
      let candidate = (start + relative, start + relative + pattern.length())
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
  best
}

///|
test "adaptive literals preserve spans around cutover and view boundaries" {
  for marker in [0, 28] {
    let patterns = collision_patterns(marker)
    patterns.push(patterns[0])
    patterns.push(patterns[0] + b"a")
    let set = @bytere.LiteralSet::new(patterns).unwrap()
    for position in [0, 1, 15, 16, 31, 32, 63, 64, 255, 256, 4095, 4096, 8192] {
      let input = Bytes::make(position, b'a') + patterns[0] + b"a" + patterns[7]
      let padded = b"before" + input + b"after"
      let value = padded[6:6 + input.length()]
      for
        start in [
          0,
          1,
          15,
          16,
          position,
          position + 1,
          0,
          value.length(),
          -1,
          value.length() + 1,
        ] {
        let expected = literal_oracle(patterns, value, start)
        assert_eq(set.find_span(value, start~), expected)
        let any = set.find_any(value, start~)
        assert_eq(any is Some(_), expected is Some(_))
        if any is Some((left, right)) {
          assert_true(left >= start)
          assert_true(patterns.any(pattern => value[left:right] == pattern[:]))
        }
      }
    }
    assert_true(!set.matches(Bytes::make(8192, b'a')))
    assert_true(!set.matches(Bytes::make(8192, b'Z')))
    assert_true(set.matches(patterns[15]))
  }
}

///|
test "lazy literal tables own patterns and preserve arbitrary bytes" {
  let patterns = collision_patterns(28)
  patterns.push(Bytes::make(28, b'a') + b"\x00\xffaa")
  let original = patterns.copy()
  let set = @bytere.LiteralSet::new(patterns).unwrap()
  patterns[0] = b"zzz"
  patterns.clear()
  for literal in original {
    let input = Bytes::make(8192, b'a') + literal
    assert_eq(set.find_span(input), literal_oracle(original, input, 0))
  }
  assert_true(set.contains_byte(b'\x00'))
  assert_true(set.contains_byte(b'\xff'))
  assert_eq(set.find_span(b"zzz"), None)
}

///|
test "failed adaptive construction preserves long budget-bound patterns" {
  let patterns = Array::makei(16, number => {
    Bytes::makei(256, index => {
      if index == 0 {
        (98 + number).to_byte()
      } else {
        b'a'
      }
    })
  })
  let set = @bytere.LiteralSet::new(patterns).unwrap()
  for literal in patterns {
    let input = Bytes::make(8192, b'a') + literal
    assert_eq(set.find_span(input), Some((8192, input.length())))
    assert_eq(set.find_any(input), Some((8192, input.length())))
  }
  assert_true(!set.matches(Bytes::make(8192, b'a')))
  assert_true(!set.matches(Bytes::make(8192, b'Z')))
}
