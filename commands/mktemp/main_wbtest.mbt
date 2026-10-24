///|
test "template replacement keeps prefix and requires a suffix" {
  let value = parse_template("/tmp/example.XXXXXX", None).fill()
  assert_true(value.has_prefix("/tmp/example."))
  assert_eq(value.length(), "/tmp/example.".length() + 6)
  try parse_template("/tmp/no-suffix", None) catch {
    MktempError(message) => assert_true(message.contains("too few X's"))
  } noraise {
    _ => fail("expected an invalid template error")
  }
}

///|
async test "random names differ across attempts" {
  let first = parse_template("/tmp/a.XXXXXX", None).fill()
  let second = parse_template("/tmp/a.XXXXXX", None).fill()
  assert_true(first != second)
}
