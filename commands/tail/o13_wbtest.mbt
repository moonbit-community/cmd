///|
test "tail NUL record selection preserves final terminators and byte mode" {
  assert_eq(
    select_lines(b"a\x00b\x00c", Last(2), delimiter=b'\x00').to_owned(),
    b"b\x00c",
  )
  assert_eq(
    select_lines(b"a\x00b\x00c", FromStart(2), delimiter=b'\x00').to_owned(),
    b"b\x00c",
  )
  assert_eq(
    select_lines(b"a\x00b\x00", Last(1), delimiter=b'\x00').to_owned(),
    b"b\x00",
  )
  assert_eq(select_lines(b"a\x00b", Last(0), delimiter=b'\x00').to_owned(), b"")
  assert_eq(select_bytes(b"a\x00b\x00c", Last(2)).to_owned(), b"\x00c")
  assert_eq(count_newlines(b"a\nb\x00c", delimiter=b'\x00'), 1)
}
