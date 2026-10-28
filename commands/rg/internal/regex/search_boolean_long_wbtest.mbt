///|
test "wide earliest endpoints agree including replay and end of input" {
  for
    pattern in [
      "[0-9]{4}.*Q|ZZ", "a+z|b+x", "a.*?b", "\\p{Greek}+[0-9]+", "[a-z&&0-9]", "foo|foobar",
    ] {
    let re = Regex::new(pattern)
    for padding in [0, 1, 2, 3, 4, 63, 64, 65, 262143, 262144, 262145] {
      let data = b"0001aaaa" +
        Bytes::make(padding, b'x') +
        b"QZZ\naaaaz\n" +
        b"\xcf\x80342\n" +
        b"bxxx"
      let hay = data.to_fixedarray()
      for offset in 0..<5 {
        for tail in 0..<12 {
          let end = hay.length() - tail
          let expected = re
            .search_half(hay, offset, end, offset, end, earliest=true)
            .unwrap_or(-1)
          if re.search_boolean_long(hay, offset, end) is Some(actual) {
            assert_eq(actual, expected, msg=pattern)
          }
        }
      }
    }
  }
}

///|
test "wide discovery declines look context and preserves necessary-prefix rejection" {
  let hay = b"aaa\n0001 gamma\n".to_fixedarray()
  for pattern in ["^aaa", "gamma$", "\\bgamma\\b", "", "a*", "(a|b)*a[ab]{9}"] {
    let re = Regex::new(pattern)
    assert_eq(re.search_boolean_long(hay, 0, hay.length()), None, msg=pattern)
  }
}
