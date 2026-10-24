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

///|
test "fmt tagged continuation preserves the prefix without negative padding" {
  assert_eq(
    format(
      b">> alpha beta gamma delta epsilon zeta eta theta\n",
      24,
      22,
      false,
      false,
      tagged=true,
      prefix=">> ",
    ),
    b">> alpha beta gamma\n>>delta epsilon zeta\n>>eta theta\n",
  )
  assert_eq(
    format(
      b"A single line alpha beta gamma delta epsilon zeta eta theta iota\n",
      24,
      22,
      false,
      false,
      tagged=true,
    ),
    b"A single line alpha beta\n   gamma delta epsilon\n   zeta eta theta iota\n",
  )
}

///|
test "fmt prefix eligibility preserves unmatched and partial EOF records" {
  assert_eq(
    format(
      b"plain untouched long line with no newline",
      24,
      22,
      false,
      false,
      prefix=">> ",
    ),
    b"plain untouched long line with no newline",
  )
  assert_eq(format(b">", 24, 22, false, false, prefix=">> "), b">")
  assert_eq(format(b">>", 24, 22, false, false, prefix=">> "), b">>\n")
}
