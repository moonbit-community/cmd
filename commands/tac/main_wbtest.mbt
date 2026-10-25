///|
test "tac reverses newline records and preserves a trailing separator" {
  assert_eq(
    reverse_records(b"one\ntwo\nthree\n", b"\n", false),
    b"three\ntwo\none\n",
  )
  assert_eq(
    reverse_records(b"one\ntwo\nthree", b"\n", false),
    b"threetwo\none\n",
  )
}

///|
test "tac supports a fixed multi-byte separator" {
  assert_eq(reverse_records(b"a--b--c", b"--", false), b"cb--a--")
  assert_eq(reverse_records(b"a--b", b"--", true), b"--ba")
  assert_eq(reverse_records(b"a--b--", b"--", true), b"----ba")
}

///|
test "tac regex uses bounded rightmost spans including empty matches" {
  let overlap = @bytere.compile("aba", emacs=true)
  assert_eq(
    reverse_records(b"ababaX", b"aba", false, regex=Some(overlap)),
    b"Xababa",
  )
  assert_eq(
    reverse_records(b"ababaX", b"aba", true, regex=Some(overlap)),
    b"abaXab",
  )
  let nullable = @bytere.compile("a*", emacs=true)
  assert_eq(
    reverse_records(b"aaBC", b"a*", false, regex=Some(nullable)),
    b"CBaa",
  )
}
