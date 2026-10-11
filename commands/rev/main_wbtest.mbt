///|
test "rev reverses bytes within each line and preserves newlines" {
  assert_eq(reverse_lines(b"abc\n123\n"), b"cba\n321\n")
  assert_eq(reverse_lines(b"abc\n123"), b"cba\n321")
}

///|
test "rev is byte oriented for invalid UTF-8" {
  assert_eq(reverse_lines(b"a\xc3\xa9\n"), b"\xa9\xc3a\n")
}
