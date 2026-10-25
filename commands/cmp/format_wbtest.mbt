///|
test "cmp visible bytes preserve control and high byte notation" {
  for
    (byte, expected) in [
      (0x00, "^@"),
      (0x09, "^I"),
      (0x20, " "),
      (0x7F, "^?"),
      (0x80, "M-^@"),
      (0xA0, "M- "),
      (0xFF, "M-^?"),
    ] {
    assert_eq(visible_byte(byte.to_byte()), expected)
  }
}

///|
test "cmp print bytes distinguishes first and verbose columns" {
  assert_eq(
    first_difference("left", "right", 2L, 1L, 0, 255, false),
    "left right differ: char 2, line 1\n",
  )
  assert_eq(
    first_difference("left", "right", 2L, 1L, 0, 255, true),
    "left right differ: byte 2, line 1 is   0 ^@ 377 M-^?\n",
  )
  assert_eq(verbose_difference(2L, 0, 255, 1, true), "2   0 ^@   377 M-^?\n")
  assert_eq(verbose_difference(2L, b'a', b'b', 3, false), "  2 141 142\n")
}
