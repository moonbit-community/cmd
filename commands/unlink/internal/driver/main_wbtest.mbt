///|
test "unlink accepts multiple ordinary operands" {
  let parsed = command.parse(argv=["a", "b"], env=Map([]))
  assert_eq(parsed.values.get("operands"), Some(["a", "b"]))
  assert_false(parsed.flags.get("help").unwrap_or(false))
}

///|
test "unlink reports directory operands before removal" {
  try reject_directory("dir") catch {
    UnlinkError(message) => assert_true(message.contains("is a directory"))
  } noraise {
    _ => fail("expected directory rejection")
  }
}
