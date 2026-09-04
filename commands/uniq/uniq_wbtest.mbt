///|
test "comparison key applies fields then characters" {
  assert_eq(comparison_key(b"1 xa", 1, 1, Some(1), false), b"x")
  assert_eq(comparison_key(b"1 xA", 1, 1, None, true), b"xa")
}

///|
test "zero comparison width makes all selected suffixes equal" {
  assert_eq(comparison_key(b"left", 0, 0, Some(0), false), b"")
}
