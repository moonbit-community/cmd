///|
test "record splitting preserves content and byte offsets" {
  let records = split_records(b"zero\nneedle\n", b'\n')
  assert_eq(records.length(), 2)
  assert_eq(records[0].data, b"zero")
  assert_eq(records[1].data, b"needle")
  assert_eq(records[1].offset, 5L)
}

///|
test "fixed matcher accepts byte-decoded records" {
  let matcher = Matcher::Fixed(["needle"], false, false)
  let decoded = bytes_as_string(b"needle")
  assert_eq(decoded, "needle")
  assert_true(matcher.matches(decoded, false))
}
