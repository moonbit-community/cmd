///|
test "test exposes portable file predicates" {
  assert_true(is_unary("-L"))
  assert_true(is_unary("-s"))
  assert_true(is_binary("-nt"))
  assert_true(is_binary("-ot"))
}
