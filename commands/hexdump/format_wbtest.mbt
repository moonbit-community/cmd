///|
test "hexdump canonical byte spacing and ASCII" {
  assert_eq(
    render_row(b"abc", 0L, "canonical"),
    "00000000  61 62 63                                          |abc|\n",
  )
  assert_eq(
    render_row(b"0123456789abcdef", 16L, "canonical"),
    "00000010  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|\n",
  )
}

///|
test "hexdump short two byte rows zero pad final word and space pad missing words" {
  assert_eq(
    render_row(b"abc", 0L, "default"),
    "0000000 6261 0063                              \n",
  )
  assert_eq(
    render_row(b"abc", 0L, "two-bytes-hex"),
    "0000000    6261    0063                                                \n",
  )
  assert_eq(
    render_row(b"abc", 0L, "two-bytes-decimal"),
    "0000000   25185   00099                                                \n",
  )
}

///|
test "hexdump C locale escapes and count suffixes" {
  assert_eq(
    render_row(b"abc", 0L, "one-byte-hex"),
    "0000000  61  62  63                                                    \n",
  )
  assert_eq(character(b'\x00'), " \\0")
  assert_eq(character(b'\xff'), "377")
  assert_eq(parse_count("0x10"), 16L)
  assert_eq(parse_count("2KiB"), 2048L)
  assert_eq(parse_count("2KB"), 2000L)
}

///|
test "hexdump squeezing spans feed boundaries" {
  let state : DumpState = {
    modes: ["canonical"],
    verbose: false,
    pending: [],
    skip: 0L,
    remaining: None,
    offset: 0L,
    previous: None,
    squeezed: false,
  }
  assert_eq(state.feed(b"01234567"), "")
  assert_eq(
    state.feed(b"89abcdef0123456789abcdef0123456789abcdef"),
    "00000000  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|\n*\n",
  )
  assert_eq(state.offset, 48L)
}
