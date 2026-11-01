///|
test "wide count table agrees with compact table for tails offsets and bytes" {
  for
    pattern in [
      "[0-9]{4}.*gamma", "a+z|b+x", "(ab){2,4}z", "a.*?b", "\\p{Greek}+[0-9]+", "[a-z&&0-9]",
    ] {
    let regex = Regex::new(pattern)
    let plan = regex.fwd.record_boolean().unwrap()
    let hay = (b"0001 gamma\nxxxx gamma\nababz\naaaab\n\xff\x00\n".repeat(32) +
    b"0002 gamma").to_fixedarray()
    for offset in 0..<24 {
      for tail in 0..<16 {
        let end = hay.length() - tail
        assert_eq(
          plan.count_long_lines(hay, offset, end, b'\n'),
          plan.count_lines(hay, offset, end, b'\n'),
          msg=pattern,
        )
      }
    }
    let arbitrary = FixedArray::makei(4096, i => (i % 256).to_byte())
    for term in [b'\n', b'\x00', b'\xff'] {
      assert_eq(
        plan.count_long_lines(arbitrary, 0, arbitrary.length(), term),
        plan.count_lines(arbitrary, 0, arbitrary.length(), term),
        msg=pattern,
      )
    }
  }
}

///|
test "long self loops retain tail hits and frequent escape transitions" {
  for pattern in ["[0-9]{4}.*gamma", "[0-9]{4}.*Q|ZZ", "a+b", "a.*?b"] {
    let regex = Regex::new(pattern)
    let plan = regex.fwd.record_boolean().unwrap()
    for
      size in [
        63, 64, 65, 127, 128, 129, 4095, 4096, 4097, 262143, 262144, 262145,
      ] {
      for suffix in [b"", b"gamma", b"Q", b"ZZ", b"ab", b"\n0002 gamma\n"] {
        let hay = (b"0001aaaa" + Bytes::make(size, b'x') + suffix).to_fixedarray()
        assert_eq(
          plan.count_long_lines(hay, 0, hay.length(), b'\n'),
          plan.count_lines(hay, 0, hay.length(), b'\n'),
          msg=pattern,
        )
      }
    }
    let hay = (b"0001gammxQZaab".repeat(20000) + b"gamma").to_fixedarray()
    assert_eq(
      plan.count_long_lines(hay, 0, hay.length(), b'\n'),
      plan.count_lines(hay, 0, hay.length(), b'\n'),
      msg=pattern,
    )
  }
}
