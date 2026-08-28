///|
test "normalizes line endings and paths" {
  assert_eq(normalize_lf("a\r\nb\rc\n"), "a\nb\nc\n")
  assert_eq(
    normalize_diagnostic(
      "failed: /tmp/case/file\r\n",
      temporary_root="/tmp/case",
    ),
    "failed: ${TMP}/file\n",
  )
}

///|
test "compares arbitrary bytes" {
  assert_true(bytes_equal(b"\x00\xff", b"\x00\xff"))
  assert_false(bytes_equal(b"\x00\xff", b"\x00\xfe"))
}

///|
test "finds byte substrings without UTF-8 decoding" {
  assert_true(contains_bytes(b"\xffinput.txt\x00", "input.txt"))
  assert_false(contains_bytes(b"\xffinput.tx\x00", "input.txt"))
}
