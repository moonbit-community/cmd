///|
test "yes defaults to y" {
  assert_eq(output_line([]), "y\n")
}

///|
test "yes joins all strings with spaces" {
  assert_eq(output_line(["ready", "ack"]), "ready ack\n")
}
