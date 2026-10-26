///|
test "custom_decimal_format" {
  let ints : Array[Int64] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 100, 123, -1]
  let expected = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "20", "100", "123", "18446744073709551615",
  ]
  for i, n in ints {
    let start = format_decimal(n)
    let got = String::from_array(
      decimal_scratch[start:].iter().map(b => b.to_char()).collect(),
    )
    assert_eq(got, expected[i])
  }
}

///|
test "base64_basic" {
  let b64 = (s : String) => {
    let b = @utf8.encode(s).to_fixedarray()
    base64_standard(b, 0, b.length())
  }
  assert_eq(b64(""), "")
  assert_eq(b64("f"), "Zg==")
  assert_eq(b64("fo"), "Zm8=")
  assert_eq(b64("foo"), "Zm9v")
  assert_eq(b64("foob"), "Zm9vYg==")
  assert_eq(b64("fooba"), "Zm9vYmE=")
  assert_eq(b64("foobar"), "Zm9vYmFy")
}

///|
test "trim_ascii_prefix" {
  let buf : FixedArray[Byte] = b"  \t\nfoo".to_fixedarray()
  let m = trim_ascii_prefix(
    @matcher.LineTerminator::default(),
    buf,
    0,
    @matcher.Match::new(0, buf.length()),
  )
  // Stops at the line terminator.
  assert_eq(m, @matcher.Match::new(3, 7))
  let buf : FixedArray[Byte] = b"  \x0b\x0cfoo".to_fixedarray()
  let m = trim_ascii_prefix(
    @matcher.LineTerminator::default(),
    buf,
    0,
    @matcher.Match::new(0, buf.length()),
  )
  assert_eq(m, @matcher.Match::new(4, 7))
}

///|
test "debug_byte" {
  assert_eq(debug_byte(b'\x00'), "\"\\0\"")
  assert_eq(debug_byte(b'\xff'), "\"\\xff\"")
  assert_eq(debug_byte(b'\x7f'), "\"\\x7f\"")
  assert_eq(debug_byte(b'a'), "\"a\"")
  assert_eq(debug_byte(b'\n'), "\"\\n\"")
}

///|
test "is_valid_utf8" {
  let check = (b : Bytes) => {
    let f = b.to_fixedarray()
    is_valid_utf8(f, 0, f.length())
  }
  assert_true(check(b"abc"))
  assert_true(check(@utf8.encode("héllo☃😀")))
  assert_false(check(b"\xff"))
  assert_false(check(b"\xc3"))
  assert_false(check(b"\xe2\x98"))
  assert_false(check(b"\xed\xa0\x80"))
  assert_false(check(b"\xc0\x80"))
  assert_false(check(b"\xf4\x90\x80\x80"))
}

///|
test "format_duration_human" {
  assert_eq(format_duration_human(0), "0.000000s")
  assert_eq(format_duration_human(36296), "0.000036s")
  assert_eq(format_duration_human(1_500_000_000), "1.500000s")
  assert_eq(format_duration_human(123_456_789_012), "123.456789s")
  // 0.0000005s is not exactly representable; the double is slightly below.
  assert_eq(format_duration_human(500), "0.000000s")
  assert_eq(format_duration_human(1500), "0.000002s")
  // 1/128 seconds = 0.0078125 exactly: ties round to even.
  assert_eq(format_duration_human(7_812_500), "0.007812s")
  assert_eq(format_fixed(2.5, 0), "2")
  assert_eq(format_fixed(3.5, 0), "4")
  assert_eq(format_fixed(0.1, 3), "0.100")
}

///|
test "grapheme_end_after" {
  let check = (s : Bytes, n : Int64) => {
    let f = s.to_fixedarray()
    grapheme_end_after(f, 0, f.length(), n)
  }
  assert_eq(check(b"abcdef", 3), 3)
  assert_eq(check(b"abc", 10), 3)
  assert_eq(check(b"abc", 0), 0)
  // e + combining acute accent is one grapheme.
  assert_eq(check(@utf8.encode("e\u{301}x"), 1), 3)
  // CRLF is one grapheme.
  assert_eq(check(b"\r\nx", 1), 2)
  // Regional indicator pairs.
  assert_eq(check(@utf8.encode("\u{1F1FA}\u{1F1F8}\u{1F1EB}"), 1), 8)
  // Emoji ZWJ sequence.
  assert_eq(check(@utf8.encode("\u{1F468}\u{200D}\u{1F469}x"), 1), 11)
  // Hangul syllables L V T.
  assert_eq(check(@utf8.encode("\u{1100}\u{1161}\u{11A8}x"), 1), 9)
  // Invalid UTF-8 is consumed as maximal subparts.
  assert_eq(check(b"\xe2\x98x", 1), 2)
  assert_eq(check(b"\xffx", 1), 1)
}
