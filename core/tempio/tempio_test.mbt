///|
async test "temporary directories are exclusive, scoped and idempotently cleaned" {
  let parent = @tempio.Directory::new(prefix="cmd-tempio-test-")
  defer parent.close()
  let a = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  let b = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  assert_true(a.path() != b.path())
  @fs.write_file(a.path() + "/record", b"data")
  a.close()
  a.close()
  b.close()
  assert_eq(@fs.readdir(parent.path()).length(), 0)
}
