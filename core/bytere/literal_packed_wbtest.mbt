///|
fn packed_classes(patterns : Array[Bytes]) -> FixedArray[Int32] {
  let classes = FixedArray::make(256, 0)
  let mut next = 1
  for pattern in patterns {
    for byte in pattern {
      if classes[byte.to_int()] == 0 {
        classes[byte.to_int()] = next
        next += 1
      }
    }
  }
  classes
}

///|
test "packed transitions preserve maximum depth and all 256 byte classes" {
  let pattern = Bytes::makei(1023, index => (index % 256).to_byte())
  let patterns = [pattern]
  let automaton = LiteralAutomaton::new(patterns, packed_classes(patterns)).unwrap()
  assert_eq(automaton.transitions.length(), 1024 * 257)
  let input = b"prefix" + pattern + pattern + b"suffix"
  for start in [0, 1, 6, 7, 32, 1028, 1029, 1030, input.length()] {
    let expected = input[start:]
      .find(pattern)
      .map(offset => (start + offset, start + offset + pattern.length()))
    assert_eq(automaton.search(input, start, false), expected)
    assert_eq(automaton.search(input, start, true), expected)
  }
  let too_deep = [pattern + b"a"]
  assert_true(LiteralAutomaton::new(too_deep, packed_classes(too_deep)) is None)
}

///|
test "packed failure transitions retain longest accepted suffix and earliest endpoint" {
  let patterns = [b"abcdef", b"bc", b"c", b"bcd", b"de", b"ef", b"f"]
  let automaton = LiteralAutomaton::new(patterns, packed_classes(patterns)).unwrap()
  for input in [b"abcdef", b"zabcdef", b"abcdex", b"abbcdef", b"ef", b"none"] {
    for start in 0..<=input.length() {
      let mut best : (Int32, Int32)? = None
      let mut first : (Int32, Int32)? = None
      for pattern in patterns {
        if input[start:].find(pattern) is Some(offset) {
          let span = (start + offset, start + offset + pattern.length())
          if best is None ||
            (
              best is Some(old) &&
              (span.0 < old.0 || (span.0 == old.0 && span.1 > old.1))
            ) {
            best = Some(span)
          }
          if first is None ||
            (
              first is Some(old) &&
              (span.1 < old.1 || (span.1 == old.1 && span.0 < old.0))
            ) {
            first = Some(span)
          }
        }
      }
      assert_eq(automaton.search(input, start, false), best)
      assert_eq(automaton.search(input, start, true), first)
    }
  }
}
