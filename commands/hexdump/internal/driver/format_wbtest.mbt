///|
test "hexdump squeezing spans feed boundaries" {
  let state : DumpState = {
    program: @format.finish_program([Builtin("canonical")]),
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
