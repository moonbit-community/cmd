///|
test "set expansion handles escapes equivalence and repetition" {
  assert_eq(@sets.expand_set_details("\\141\\142", None).bytes, [b'a', b'b'])
  assert_eq(@sets.expand_set_details("[=a=]", None).bytes, [b'a'])
  assert_eq(@sets.expand_set_details("\\400", None).bytes, [b' ', b'0'])
  assert_eq(@sets.expand_set_details("[X*3]", Some(0)).bytes, [b'X', b'X', b'X'])
  assert_eq(@sets.expand_set_details("[X*010]", Some(0)).bytes.length(), 8)
  assert_eq(@sets.expand_set_details("[X*]", Some(3)).bytes, [b'X', b'X', b'X'])
  try @sets.expand_set_details("[X*]", None) catch {
    @sets.CliError(_) => ()
  } noraise {
    _ => fail("repetition must be rejected in SET1")
  }
}
