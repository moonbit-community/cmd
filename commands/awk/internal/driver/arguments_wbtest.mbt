///|
test "Record separator names are distinguished from output separators" {
  assert_eq(input_features("{ORS = \"!\"; print}"), (false, false, false))
  assert_eq(input_features("{print RT}"), (true, false, false))
  assert_eq(input_features("BEGIN {RS=\":\"}"), (true, false, false))
}

///|
test "Named getline leaves the main input available for streaming" {
  assert_eq(input_features("{getline x < \"names\"}"), (false, false, false))
  assert_eq(input_features("{getline < \"/dev/stdin\"}"), (false, false, true))
  assert_eq(input_features("{getline x < path}"), (false, false, true))
  assert_eq(input_features("{getline x}"), (false, true, false))
}

///|
test "Command line assignment names are ASCII identifiers" {
  assert_eq(assignment("_a2=x=y"), Some(("_a2", "x=y")))
  assert_eq(assignment("2a=x"), None)
  assert_eq(assignment("x-y=4"), None)
}
