///|
test "hexdump canonical byte spacing and ASCII" {
  assert_eq(
    @format.render_row(b"abc", 0L, "canonical"),
    "00000000  61 62 63                                          |abc|\n",
  )
  assert_eq(
    @format.render_row(b"0123456789abcdef", 16L, "canonical"),
    "00000010  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|\n",
  )
}

///|
test "hexdump short two byte rows zero pad final word and space pad missing words" {
  assert_eq(
    @format.render_row(b"abc", 0L, "default"),
    "0000000 6261 0063                              \n",
  )
  assert_eq(
    @format.render_row(b"abc", 0L, "two-bytes-hex"),
    "0000000    6261    0063                                                \n",
  )
  assert_eq(
    @format.render_row(b"abc", 0L, "two-bytes-decimal"),
    "0000000   25185   00099                                                \n",
  )
}

///|
test "hexdump custom formats preserve bytes and partial elements" {
  let hex = @format.compile_format(b"4/1 \"%02x \" \"\\n\""[:], false)
  assert_eq(@format.render_custom(hex, b"ABC"[:], 0L, 4), b"41 42 43   \n")
  let words = @format.compile_format(b"2/4 \"%08x \" \"\\n\""[:], false)
  assert_eq(
    @format.render_custom(words, b"ABCDE"[:], 0L, 8),
    b"44434241 00000045\n",
  )
  let raw = @format.compile_format(b"4/1 \"%c\""[:], false)
  assert_eq(@format.render_custom(raw, b"A\x00\xffB"[:], 0L, 4), b"A\x00\xffB")
  let strings = @format.compile_format(b"1/4 \"[%8s]\\n\""[:], false)
  assert_eq(
    @format.render_custom(strings, b"ABC\x00"[:], 0L, 4),
    b"[     ABC]\n",
  )
}

///|
test "hexdump custom float and signed byte conversion" {
  let floating = @format.compile_format(b"1/8 \"%+.20g\\n\""[:], false)
  assert_eq(
    @format.render_custom(
      floating,
      b"\x9a\x99\x99\x99\x99\x99\xb9\x3f"[:],
      0L,
      8,
    ),
    b"+0.10000000000000000555\n",
  )
  assert_eq(
    @format.render_custom(
      floating,
      b"\x00\x00\x00\x00\x00\x00\x00\x80"[:],
      0L,
      8,
    ),
    b"-0\n",
  )
  let signed = @format.compile_format(b"2/1 \"%+04d \""[:], false)
  assert_eq(@format.render_custom(signed, b"A\xff"[:], 0L, 2), b"+065 -001")
  let escaped = @format.compile_format(b"\"%.1_c %.2_u\""[:], false)
  assert_eq(@format.render_custom(escaped, b"\x00\x00"[:], 0L, 2), b"\\ nu")
}

///|
test "hexdump custom color rules and format rejection" {
  let colors = @format.compile_format(
    b"1/1 \"%02x_L[!red:0x41@0,green:0x41@0]\\n\""[:],
    true,
  )
  assert_eq(
    @format.render_custom(colors, b"A"[:], 0L, 1),
    b"\x1b[32m41\x1b[0m\n",
  )
  assert_eq(@format.render_custom(colors, b"B"[:], 1L, 1), b"42\n")
  let disabled = @format.compile_format(b"\"%02x_L[nonesuch:A@0-3]\""[:], false)
  assert_eq(@format.render_custom(disabled, b"ABCD"[:], 0L, 4), b"44434241")
  let unknown = @format.compile_format(b"1/1 \"%02x_L[nonesuch]\""[:], true)
  assert_eq(@format.render_custom(unknown, b"A"[:], 0L, 1), b"41")
  let invalid = try {
    ignore(@format.compile_format(b"\"%%\""[:], false))
    ""
  } catch {
    @format.FormatError(message) => message
  }
  assert_eq(invalid, "bad conversion character %%")
}
