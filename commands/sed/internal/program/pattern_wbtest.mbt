///|
test "sed byte rejection preserves the full matcher for nullable alternatives captures and binary data" {
  for extended in [false, true] {
    let sources = [
      "", "^", "$", "ab", "^ab$", "ab.*cd", "a*b*", "a?b?", "[ab]+", "a\nb", "\u00ff\u0000",
    ]
    sources.append(
      if extended {
        ["(ab|cd)", "(ab)?", "(ab)+", "(ab)\\1", "a{0,2}"]
      } else {
        ["\\(ab\\)\\1", "ab\\|cd", "\\(ab\\)\\?", "a\\{0,2\\}"]
      },
    )
    for source in sources {
      let pattern = @bytere.compile(source, extended~)
      let prepared = PreparedPattern::new(pattern)
      for
        bytes in [
          b"", b"a", b"ab", b"cd", b"abab", b"abZZcd", b"a\nb", b"\xff\x00", b"\x00\xff",
        ] {
        let expected = pattern.is_match(@bytere.text(bytes[:]))
        let space = Space::from_bytes(bytes[:], false)
        if prepared.rejects(space) {
          assert_false(expected, msg=source)
        }
        assert_eq(prepared.matches(space), expected, msg=source)
        let text_space = Space::from_text(@bytere.text(bytes[:]), false)
        assert_false(prepared.rejects(text_space))
        assert_eq(prepared.matches(text_space), expected, msg=source)
      }
    }
  }
}
