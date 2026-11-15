///|
async test "rmdir attempts real removal and distinguishes ignored nonempty from removed" {
  let root = @fs.tmpdir(prefix="cmd-rmdir-removal-")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/empty")
  @fs.mkdir(root + "/nonempty")
  @fs.write_file(root + "/nonempty/kept", "retained")
  assert_eq(remove_directory(root + "/empty", true, false), true)
  assert_true(!@fs.exists(root + "/empty"))
  assert_eq(remove_directory(root + "/nonempty", true, false), false)
  assert_eq(@fs.read_file(root + "/nonempty/kept").text(), "retained")
  for path in [root + "/missing", root + "/nonempty/kept"] {
    assert_true(
      try {
        ignore(remove_directory(path, true, false))
        false
      } catch {
        _ => true
      },
    )
  }
  if !(@async.platform is Windows) {
    @fs.symlink(root + "/link", target=root + "/nonempty", force_symlink=true)
    assert_true(
      try {
        ignore(remove_directory(root + "/link", true, false))
        false
      } catch {
        _ => true
      },
    )
    assert_true(@fs.kind(root + "/link", follow_symlink=false) == SymLink)
    assert_eq(@fs.read_file(root + "/nonempty/kept").text(), "retained")
  }
}
