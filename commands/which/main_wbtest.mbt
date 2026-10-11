///|
test "which detects path operands without shell lookup" {
  assert_true(has_separator("./tool"))
  assert_true(has_separator("bin\\tool"))
  assert_false(has_separator("tool"))
}

///|
test "which uses the platform path separator" {
  assert_true(path_separator() == ":" || path_separator() == ";")
}
