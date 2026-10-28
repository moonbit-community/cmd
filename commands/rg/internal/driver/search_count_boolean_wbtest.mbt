///|
test "dense boolean counts agree with existing per-record engine" {
  let body = b"0001 alpha gamma\n0002 miss\n0003 gamma gamma\ncat dog tail\naaaab\nababz\n\xff\x00gamma\n"
  let input = body.repeat(256) + b"0004 gamma"
  let hay = input.to_fixedarray()
  for
    pattern in [
      "[0-9]{4}.*gamma", "[0-9]{4}.*absent_xyz", "a+z|b+x", "(?:cat|dog).*tail",
      "(ab){2,4}z", "a.*?b", "a.*b", "\\bgamma\\b", "^0001", "gamma$", "", "alpha",
      "gamma|miss",
    ] {
    let matcher = SearchMatcher::new(
      [pattern],
      line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
    )
    for offset in 0..<32 {
      let mut expected = 0L
      let mut start = offset
      for i in offset..<hay.length() {
        if hay[i] == b'\n' {
          if @matcher.is_match_at(matcher, hay, start, i, 0) {
            expected += 1L
          }
          start = i + 1
        }
      }
      if start < hay.length() &&
        @matcher.is_match_at(matcher, hay, start, hay.length(), 0) {
        expected += 1L
      }
      if @matcher.Matcher::count_matching_lines(
          matcher,
          hay,
          offset,
          hay.length(),
          b'\n',
        )
        is Some(actual) {
        assert_eq(actual, expected, msg=pattern)
      }
    }
  }
}

///|
test "boolean count plans decline empty and assertions and handle arbitrary bytes" {
  for pattern in ["", "^x", "x$", "\\bx\\b", "a*"] {
    let re = @regex.Regex::new(pattern)
    let hay = b"x\na\n".to_fixedarray()
    assert_eq(re.count_boolean_lines(hay, 0, hay.length(), b'\n'), None)
  }
  let re = @regex.Regex::new("[0-9]{4}.*gamma")
  for
    hay in [
      b"", b"\n", b"0001 gamma", b"0001 gamma\n", b"0001 gamma\n\n", b"0001 gamma\x00\n0002 gamma",
    ] {
    let expected = if hay.is_empty() || hay == b"\n" {
      0L
    } else if hay == b"0001 gamma\x00\n0002 gamma" {
      2L
    } else {
      1L
    }
    assert_eq(
      re.count_boolean_lines(hay.to_fixedarray(), 0, hay.length(), b'\n'),
      Some(expected),
    )
  }
}

///|
test "boolean count adapter selects direct byte rows for oversized records" {
  let matcher = SearchMatcher::new(
    ["[0-9]{4}.*gamma"],
    line_terminator=Some(@matcher.LineTerminator::byte(b'\n')),
  )
  let prefix = b"0001 gamma\n".repeat(32)
  let hay = (prefix + Bytes::make(262145 - prefix.length(), b'x')).to_fixedarray()
  assert_eq(
    @matcher.Matcher::count_matching_lines(matcher, hay, 0, 262144, b'\n'),
    Some(32L),
  )
  assert_eq(
    @matcher.Matcher::count_matching_lines(matcher, hay, 0, 262145, b'\n'),
    Some(32L),
  )
}
