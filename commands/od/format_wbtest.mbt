///|
test "od integer bases and partial zero padded word" {
  assert_eq(
    render_row(b"abc", 0L, 16, parse_formats("o2"), 8, false),
    "0000000 061141 000143\n",
  )
  assert_eq(
    render_row(b"abc", 0L, 16, parse_formats("x1"), 16, false),
    "000000 61 62 63\n",
  )
  assert_eq(
    render_row(b"\xff\x80", 0L, 16, parse_formats("d1"), 0, false),
    "   -1 -128\n",
  )
  assert_eq(
    render_row(
      b"\xff\xff\xff\xff\xff\xff\xff\xff",
      0L,
      16,
      parse_formats("u8"),
      0,
      false,
    ),
    " 18446744073709551615\n",
  )
}

///|
test "od named and escaped bytes" {
  assert_eq(
    render_row(b"a\n\x00\xff", 0L, 16, parse_formats("c"), 0, false),
    "   a  \\n  \\0 377\n",
  )
  assert_eq(
    render_row(b" \n\xff", 0L, 16, parse_formats("a"), 0, false),
    "  sp  nl del\n",
  )
}

///|
test "od endian and 64 bit signed output" {
  assert_eq(
    render_row(b"\x01\x02", 0L, 16, parse_formats("x2"), 0, true),
    " 0102\n",
  )
  assert_eq(
    render_row(
      b"\xff\xff\xff\xff\xff\xff\xff\xff",
      0L,
      16,
      parse_formats("d8"),
      0,
      false,
    ),
    "                   -1\n",
  )
  assert_eq(parse_count("0x10"), 16L)
  assert_eq(parse_count("010"), 8L)
  assert_eq(parse_count("2K"), 2048L)
}

///|
test "od duplicate rows and skip limit preserve absolute address" {
  let state = settings(
    @cli.parse(["-t", "x1", "-j", "2", "-N", "4", "-w4"], [
      @cli.option("format", short='t'),
      @cli.option("skip-bytes", short='j'),
      @cli.option("read-bytes", short='N'),
      @cli.option("width", short='w'),
    ]),
  )
  assert_eq(state.feed(b"xxab"), "")
  assert_eq(state.feed(b"cdyz"), "0000002 61 62 63 64\n")
  assert_eq(state.offset, 6L)
  assert_eq(state.remaining, Some(0L))
  let repeated = settings(
    @cli.parse(["-t", "x1", "-w4"], [
      @cli.option("format", short='t'),
      @cli.option("width", short='w'),
    ]),
  )
  assert_eq(repeated.feed(b"abcdabcdabcd"), "0000000 61 62 63 64\n*\n")
  assert_eq(repeated.offset, 12L)
}
