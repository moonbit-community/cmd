///|
test "valid UTF-8 round trips" {
  for s in ["", "abc", "héllo", "日本語", "😀 x", "\u{10FFFF}"] {
    let b = @osstr.encode(s)
    assert_eq(@osstr.decode(b), s)
    assert_false(@osstr.has_escapes(s))
  }
}

///|
test "invalid bytes are escaped and restored" {
  let cases : Array[Bytes] = [
    b"foo\xFFbar", b"\x80", b"\xC3", b"\xC0\xAF", b"\xED\xA0\x80", b"\xF4\x90\x80\x80",
    b"a\xE2\x82", b"\xE2\x82\xAC\xFF", b"\xF0\x9F\x98\x80\xF0",
  ]
  for b in cases {
    let s = @osstr.decode(b)
    assert_true(@osstr.has_escapes(s))
    assert_eq(@osstr.encode(s), b)
  }
  let s = @osstr.decode(b"foo\xFFbar")
  assert_eq(s.length(), 7)
  assert_eq(s.code_unit_at(3).to_int(), 0xDCFF)
  assert_eq(@osstr.decode(b"\xE2\x82\xAC"), "€")
}

///|
test "every byte pair round trips" {
  for i in 0..<256 {
    for j in 0..<256 {
      let b = Bytes::from_array([i.to_byte(), j.to_byte()])
      assert_eq(@osstr.encode(@osstr.decode(b)), b)
    }
  }
}

///|
test "lossy display and whitespace" {
  assert_eq(@osstr.to_lossy(@osstr.decode(b"bad\xFF")), "bad\u{FFFD}")
  // One replacement per maximal invalid sequence, like Rust.
  assert_eq(@osstr.to_lossy(@osstr.decode(b"a\xE2\x82b")), "a\u{FFFD}b")
  assert_eq(@osstr.to_lossy("plain"), "plain")
  assert_eq(@osstr.trim_white_space("\u{A0} x y\u{3000}\n"), "x y")
  assert_eq(@osstr.trim_white_space("\u{200B}x"), "\u{200B}x")
}
