///|
test "template replacement keeps prefix and requires a suffix" {
  let value = fill_template("/tmp/example.XXXXXX")
  assert_true(value.has_prefix("/tmp/example."))
  assert_eq(value.length(), "/tmp/example.".length() + 6)
  try fill_template("/tmp/no-suffix") catch {
    MktempError(message) => assert_true(message.has_suffix("3 X's"))
  } noraise {
    _ => fail("expected an invalid template error")
  }
}

///|
async test "random names differ across attempts" {
  let first = fill_template("/tmp/a.XXXXXX")
  let second = fill_template("/tmp/a.XXXXXX")
  assert_true(first != second)
}
