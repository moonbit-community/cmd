///|
test "locale quote preserves apostrophe backslash and C byte escapes" {
  assert_eq(locale_quote(b"a'b"[:]), "'a\\'b'")
  assert_eq(locale_quote(b"\\"[:]), "'\\\\'")
  assert_eq(locale_quote(b"\xc3\xa9"[:]), "'\\303\\251'")
}
