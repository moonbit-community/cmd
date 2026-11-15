///|
test "realpath options parse existing and zero modes" {
  let parsed = @cli.parse(["-ez", "--", "one", "two"], [
    @cli.flag("canonicalize-existing", short='e'),
    @cli.flag("zero", short='z'),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  assert_true(parsed.contains("canonicalize-existing"))
  assert_true(parsed.contains("zero"))
  assert_false(parsed.contains("help"))
  assert_false(parsed.contains("version"))
  assert_eq(parsed.operands, ["one", "two"])
}

///|
async test "realpath resolves an existing file and rejects a missing path" {
  let root = @fs.tmpdir(prefix="mooncmd-realpath")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file_path = root + "/entry"
  let file = @fs.open(file_path, mode=WriteOnly, create_mode=CreateNew)
  file.close()
  let expected = @fs.realpath(file_path)
  assert_eq(resolve_path(file_path, Existing, false), expected)
  try resolve_path(root + "/missing", Existing, false) catch {
    error => assert_eq(error_text(error), "No such file or directory")
  } noraise {
    _ => fail("missing paths must be rejected")
  }
}
