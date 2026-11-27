///|
async test "temporary directories are exclusive, scoped and idempotently cleaned" {
  let parent = @tempio.Directory::new(prefix="cmd-tempio-test-")
  defer parent.close()
  let a = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  let b = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  assert_true(a.path() != b.path())
  @fs.write_binary(a.path() + "/record", b"data")
  a.close()
  a.close()
  b.close()
  assert_eq(@fs.readdir(parent.path()).length(), 0)
}

///|
async test "cleanup preserves a replacement file and can retry after its removal" {
  let parent = @tempio.Directory::new(prefix="cmd-tempio-test-")
  defer parent.close()
  let child = @tempio.Directory::new(
    prefix="child-",
    parent=Some(parent.path()),
  )
  @fs.remove(child.path())
  @fs.write_binary(child.path(), b"replacement")
  try child.close() catch {
    _ => ()
  } noraise {
    _ => fail("expected directory cleanup to reject a replacement file")
  }
  assert_eq(@fs.read_binary(child.path()), b"replacement")
  @fs.remove(child.path())
  @fs.mkdir(child.path())
  child.close()
  assert_eq(@fs.readdir(parent.path()).length(), 0)
}
