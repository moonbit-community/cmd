///|
test "cp overwrite flags are absent by default" {
  let parsed = @cli.parse(["source", "destination"], [
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
    @cli.flag("interactive", short='i'),
  ]) catch {
    _ => fail("parse failed")
  }
  assert_eq(
    parsed.last_occurrence(["force", "no-clobber", "interactive"]),
    None,
  )
  assert_false(parsed.contains("interactive"))
}

///|
fn copy_options() -> CpOptions {
  {
    recursive: true,
    no_clobber: false,
    no_target_directory: false,
    verbose: false,
    traversal: NeverFollowLinks,
    update: @fsops.UpdateAll,
    preserve_permissions: false,
  }
}

///|
async test "cp shares tree preflight and rejects later conflicts before any copy" {
  let root = @fs.tmpdir(prefix="mooncmd-cp-preflight")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/source")
  @fs.mkdir(root + "/target")
  @fs.write_file(root + "/source/a", "new a")
  @fs.write_file(root + "/source/z", "new z")
  @fs.write_file(root + "/target/z", "old z")
  try copy_one(root + "/source", root + "/target", copy_options()) catch {
    @fsops.FsOpError(message) =>
      assert_true(message.contains("overwriting an existing file"))
    error => raise error
  } noraise {
    _ => fail("existing destination must be rejected")
  }
  assert_true(@fsops.kind_if_exists(root + "/target/a") is None)
  assert_eq(@fs.read_file(root + "/target/z").text(), "old z")
}

///|
async test "cp empty directory reports a change only when the target is created" {
  let root = @fs.tmpdir(prefix="mooncmd-cp-empty")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/source")
  assert_true(copy_one(root + "/source", root + "/target", copy_options()))
  assert_false(copy_one(root + "/source", root + "/target", copy_options()))
}
