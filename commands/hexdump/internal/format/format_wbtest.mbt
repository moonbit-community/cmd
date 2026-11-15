///|
test "hexdump C locale escapes" {
  assert_eq(
    render_row(b"abc", 0L, "one-byte-hex"),
    "0000000  61  62  63                                                    \n",
  )
  assert_eq(character(b'\x00'), " \\0")
  assert_eq(character(b'\xff'), "377")
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
