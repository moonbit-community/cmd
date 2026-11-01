///|
test "argument budgets count UTF-8 bytes and NUL for empty and Unicode values" {
  assert_eq(@process.argument_bytes(""), 1L)
  assert_eq(@process.argument_bytes("\u00e9"), 3L)
  assert_eq(@process.argument_bytes("\u{1F600}"), 5L)
  assert_eq(@process.arguments_bytes(["cmd", "", "\u00e9", "\u{1F600}"]), 13L)
}
