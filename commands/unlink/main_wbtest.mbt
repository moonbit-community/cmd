///|
test "unlink accepts multiple ordinary operands" {
  let parsed = @cli.parse(["a", "b"], [@cli.flag("help"), @cli.flag("version")])
  assert_eq(parsed.operands, ["a", "b"])
  assert_false(parsed.contains("help"))
}

///|
test "unlink reports directory operands before removal" {
  try reject_directory("dir") catch {
    UnlinkError(message) => assert_true(message.contains("is a directory"))
  } noraise {
    _ => fail("expected directory rejection")
  }
}
