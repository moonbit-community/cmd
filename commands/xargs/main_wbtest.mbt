///|
test "xargs tokenization and replacement keep argument boundaries" {
  assert_eq(parse_words("one 'two three' four\\ five", false), [
    "one", "two three", "four five",
  ])
  assert_eq(replacement_lines("  first line  \n\nsecond\n"), [
    "first line", "second",
  ])
  assert_eq(replace_arguments(["pre{}post", "{}"], "{}", "value"), [
    "prevaluepost", "value",
  ])
}

///|
test "xargs maps child outcomes to findutils status classes" {
  assert_eq(xargs_child_status(0), 0)
  assert_eq(xargs_child_status(1), 123)
  assert_eq(xargs_child_status(126), 123)
  assert_eq(xargs_child_status(255), 124)
  assert_eq(xargs_child_status(-9), 125)
}
