///|
test "rm operand protection follows command flags and final components" {
  assert_true(protects_removal_operand("."))
  assert_true(protects_removal_operand("dir/../"))
  assert_true(protects_removal_operand("/"))
  assert_false(protects_removal_operand("/", preserve_root=false))
  assert_true(protects_removal_operand("dir/.", preserve_root=false))
  assert_false(protects_removal_operand("/named/working/directory"))
  if @platform.is_windows() {
    assert_true(protects_removal_operand("dir\\..\\"))
    assert_true(protects_removal_operand("C:\\dir\\.\\", preserve_root=false))
  } else {
    assert_false(protects_removal_operand("dir\\..\\"))
  }
}
