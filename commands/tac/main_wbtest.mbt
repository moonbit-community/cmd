///|
test "tac reverses newline records and preserves a trailing separator" {
  assert_eq(
    reverse_records(b"one\ntwo\nthree\n", b"\n", false),
    b"three\ntwo\none\n",
  )
  assert_eq(
    reverse_records(b"one\ntwo\nthree", b"\n", false),
    b"three\ntwo\none",
  )
}

///|
test "tac supports a fixed multi-byte separator" {
  assert_eq(reverse_records(b"a--b--c", b"--", false), b"c--b--a")
  assert_eq(reverse_records(b"a--b", b"--", true), b"b--a")
  assert_eq(reverse_records(b"a--b--", b"--", true), b"--b--a")
}
