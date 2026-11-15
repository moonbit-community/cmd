///|
test "fixed C locale classes cover the byte ranges exactly" {
  assert_eq(class_bytes("blank"), [b'\t', b' '])
  assert_eq(class_bytes("cntrl").length(), 33)
  assert_eq(class_bytes("graph").length(), 94)
  assert_eq(class_bytes("print").length(), 95)
  assert_eq(class_bytes("punct").length(), 32)
}
