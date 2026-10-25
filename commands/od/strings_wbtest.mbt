///|
test "od strings retain candidates until NUL or the selected byte limit" {
  let state : StringDump = {
    minimum: 3L,
    base: 0,
    label: None,
    pending: [],
    skip: 0L,
    remaining: None,
    offset: 0L,
    start: 0L,
  }
  assert_eq(state.feed(b"xx\x00ab"[:]), "")
  assert_eq(state.feed(b"c\x00tail"[:]), "abc\n")
  assert_eq(state.pending, [b't', b'a', b'i', b'l'])
  let limited : StringDump = {
    minimum: 3L,
    base: 0,
    label: None,
    pending: [],
    skip: 0L,
    remaining: Some(3L),
    offset: 0L,
    start: 0L,
  }
  assert_eq(limited.feed(b"abcdef"[:]), "abc\n")
  assert_eq(limited.offset, 3L)
  assert_true(limited.done())
}

///|
test "od traditional offsets and labels preserve their own radix" {
  for
    (text, expected) in [
      ("10", Some(8L)),
      ("10.", Some(10L)),
      ("10b", Some(4096L)),
      ("10.b", Some(5120L)),
      ("10.B", Some(10240L)),
      ("0x10b", Some(267L)),
      ("+10", Some(8L)),
      ("8", None),
      ("name", None),
    ] {
    assert_eq(traditional_offset(text), expected)
  }
  assert_eq(
    render_row(b"ab", 2L, 16, parse_formats("x1"), 16, false, label=Some(14L)),
    "000002 (000010) 61 62\n",
  )
  assert_eq(
    render_row(b"ab", 2L, 16, parse_formats("x1"), 0, false, label=Some(14L)),
    "(0000002) 61 62\n",
  )
  for text in ["9223372036854775808.", "9223372036854775807.b"] {
    try traditional_offset(text) catch {
      OdError(message) =>
        assert_eq(message, "\{text}: Numerical result out of range")
    } noraise {
      _ => fail("a numeric offset overflow must reject before file access")
    }
  }
}
