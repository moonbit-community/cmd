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
    program: finish_program([Builtin("canonical")]),
    verbose: false,
    pending: [],
    skip: 0L,
    remaining: None,
    offset: 0L,
    previous: None,
    squeezed: false,
  }
  assert_eq(state.feed(b"01234567"), b"")
  assert_eq(
    state.feed(b"89abcdef0123456789abcdef0123456789abcdef"),
    b"00000000  30 31 32 33 34 35 36 37  38 39 61 62 63 64 65 66  |0123456789abcdef|\n*\n",
  )
  assert_eq(state.offset, 48L)
}

///|
test "hexdump custom formats preserve bytes and partial elements" {
  let hex = compile_format(b"4/1 \"%02x \" \"\\n\""[:], false)
  assert_eq(render_custom(hex, b"ABC"[:], 0L, 4), b"41 42 43   \n")
  let words = compile_format(b"2/4 \"%08x \" \"\\n\""[:], false)
  assert_eq(render_custom(words, b"ABCDE"[:], 0L, 8), b"44434241 00000045\n")
  let raw = compile_format(b"4/1 \"%c\""[:], false)
  assert_eq(render_custom(raw, b"A\x00\xffB"[:], 0L, 4), b"A\x00\xffB")
  let strings = compile_format(b"1/4 \"[%8s]\\n\""[:], false)
  assert_eq(render_custom(strings, b"ABC\x00"[:], 0L, 4), b"[     ABC]\n")
}

///|
test "hexdump custom address selection and implicit iteration" {
  let first = compile_format(b"\"%_Ad a\\n\""[:], false)
  let last = compile_format(b"\"%_Ax z\\n\""[:], false)
  let bytes = compile_format(b"/1 \"%02x \""[:], false)
  let program = finish_program([
    Custom(first),
    Custom(bytes),
    Builtin("canonical"),
    Custom(last),
  ])
  assert_eq(program.block_size, 16)
  assert_eq(bytes.units[0].reps, 16)
  assert_eq(
    render_custom(bytes, b"AB"[:], 0L, 16),
    @utf8.encode("41 42" + spaces(42)),
  )
  assert_eq(render_final(program.final_unit.unwrap(), 16L), b"10 z\n")
  assert_eq(finish_program([Custom(first)]).block_size, 0)
  let tail = compile_format(b"4/1 \"%02x \\t\""[:], false)
  assert_eq(render_custom(tail, b"ABCD"[:], 0L, 4), b"41 \t42 \t43 \t44 ")
}

///|
test "hexdump custom float and signed byte conversion" {
  let floating = compile_format(b"1/8 \"%+.20g\\n\""[:], false)
  assert_eq(
    render_custom(floating, b"\x9a\x99\x99\x99\x99\x99\xb9\x3f"[:], 0L, 8),
    b"+0.10000000000000000555\n",
  )
  assert_eq(
    render_custom(floating, b"\x00\x00\x00\x00\x00\x00\x00\x80"[:], 0L, 8),
    b"-0\n",
  )
  let signed = compile_format(b"2/1 \"%+04d \""[:], false)
  assert_eq(render_custom(signed, b"A\xff"[:], 0L, 2), b"+065 -001")
  let escaped = compile_format(b"\"%.1_c %.2_u\""[:], false)
  assert_eq(render_custom(escaped, b"\x00\x00"[:], 0L, 2), b"\\ nu")
}

///|
test "hexdump custom color rules and format rejection" {
  let colors = compile_format(
    b"1/1 \"%02x_L[!red:0x41@0,green:0x41@0]\\n\""[:],
    true,
  )
  assert_eq(render_custom(colors, b"A"[:], 0L, 1), b"\x1b[32m41\x1b[0m\n")
  assert_eq(render_custom(colors, b"B"[:], 1L, 1), b"42\n")
  let disabled = compile_format(b"\"%02x_L[nonesuch:A@0-3]\""[:], false)
  assert_eq(render_custom(disabled, b"ABCD"[:], 0L, 4), b"44434241")
  let unknown = compile_format(b"1/1 \"%02x_L[nonesuch]\""[:], true)
  assert_eq(render_custom(unknown, b"A"[:], 0L, 1), b"41")
  let invalid = try {
    ignore(compile_format(b"\"%%\""[:], false))
    ""
  } catch {
    HexdumpError(message) => message
  }
  assert_eq(invalid, "bad conversion character %%")
  assert_eq(normalized_args(["-CLalways", "-e", "\"%c\"", "--", "-L"][:]), [
    "-C", "--color=always", "-e", "\"%c\"", "--", "-L",
  ])
}
