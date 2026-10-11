///|
test "fmt control bytes have GNU word boundaries without being discarded" {
  assert_eq(
    format(b"one\x0b two\x0c three\r four\n", 20, 18, false, true),
    b"one \x0b two \x0c three\n\r four\n",
  )
  assert_eq(
    format(b"one\x0b two\x0c three\r four\n", 0, 0, false, false),
    b"one\n\x0b\ntwo\n\x0c\nthree\n\r\nfour\n",
  )
}

///|
test "fmt zero width and independent paragraphs" {
  assert_eq(format(b"alpha beta\n", 0, 0, false, false), b"alpha\nbeta\n")
  assert_eq(
    format(b"one\ntwo\n\nlast", 75, 70, false, false),
    b"one two\n\nlast\n",
  )
  assert_eq(format(b"one\ntwo\n", 75, 70, true, false), b"one\ntwo\n")
}
