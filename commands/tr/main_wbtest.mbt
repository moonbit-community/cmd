///|
test "fixed C locale classes cover the byte ranges exactly" {
  assert_eq(class_bytes("blank"), [b'\t', b' '])
  assert_eq(class_bytes("cntrl").length(), 33)
  assert_eq(class_bytes("graph").length(), 94)
  assert_eq(class_bytes("print").length(), 95)
  assert_eq(class_bytes("punct").length(), 32)
}

///|
test "set expansion handles escapes equivalence and repetition" {
  assert_eq(expand_set_details("\\141\\142", None).bytes, [b'a', b'b'])
  assert_eq(expand_set_details("[=a=]", None).bytes, [b'a'])
  assert_eq(expand_set_details("\\400", None).bytes, [b' ', b'0'])
  assert_eq(expand_set_details("[X*3]", Some(0)).bytes, [b'X', b'X', b'X'])
  assert_eq(expand_set_details("[X*010]", Some(0)).bytes.length(), 8)
  assert_eq(expand_set_details("[X*]", Some(3)).bytes, [b'X', b'X', b'X'])
  try expand_set_details("[X*]", None) catch {
    CliError(_) => ()
  } noraise {
    _ => fail("repetition must be rejected in SET1")
  }
}
