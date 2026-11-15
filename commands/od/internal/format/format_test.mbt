///|
test "od integer bases and partial zero padded word" {
  assert_eq(
    @format.render_row(b"abc", 0L, 16, @format.parse_formats("o2"), 8, false),
    "0000000 061141 000143\n",
  )
  assert_eq(
    @format.render_row(b"abc", 0L, 16, @format.parse_formats("x1"), 16, false),
    "000000 61 62 63\n",
  )
  assert_eq(
    @format.render_row(
      b"\xff\x80",
      0L,
      16,
      @format.parse_formats("d1"),
      0,
      false,
    ),
    "   -1 -128\n",
  )
  assert_eq(
    @format.render_row(
      b"\xff\xff\xff\xff\xff\xff\xff\xff",
      0L,
      16,
      @format.parse_formats("u8"),
      0,
      false,
    ),
    " 18446744073709551615\n",
  )
}

///|
test "od named and escaped bytes" {
  assert_eq(
    @format.render_row(
      b"a\n\x00\xff",
      0L,
      16,
      @format.parse_formats("c"),
      0,
      false,
    ),
    "   a  \\n  \\0 377\n",
  )
  assert_eq(
    @format.render_row(b" \n\xff", 0L, 16, @format.parse_formats("a"), 0, false),
    "  sp  nl del\n",
  )
}

///|
test "od endian and 64 bit signed output" {
  assert_eq(
    @format.render_row(
      b"\x01\x02",
      0L,
      16,
      @format.parse_formats("x2"),
      0,
      true,
    ),
    " 0102\n",
  )
  assert_eq(
    @format.render_row(
      b"\xff\xff\xff\xff\xff\xff\xff\xff",
      0L,
      16,
      @format.parse_formats("d8"),
      0,
      false,
    ),
    "                   -1\n",
  )
}
