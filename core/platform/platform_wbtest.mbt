///|
test "native separator is accepted" {
  assert_true(accepts_separator(native_separator()))
  assert_true(accepts_separator('/'))
}

///|
test "permission support follows platform" {
  assert_eq(permission_mutation_supported(), !is_windows())
  assert_eq(symbolic_links_supported(), !is_windows())
}
