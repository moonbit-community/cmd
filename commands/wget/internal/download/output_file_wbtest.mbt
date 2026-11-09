///|
async test "numbered destinations atomically create the first missing sibling" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-numbered")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "result")
  let (first_path, first) = open_unique_numbered_output(path)
  assert_eq(first_path, path)
  first.write(b"zero")
  first.close()
  @fs.write_file(path + ".1", b"one")
  let (third_path, third) = open_unique_numbered_output(path)
  assert_eq(third_path, path + ".2")
  third.close()
}

///|
async test "temporary cleanup is idempotent and refuses directories" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cleanup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fsops.join(root, "file")
  @fs.write_file(file, b"temporary")
  cleanup_file_if_exists(file)
  cleanup_file_if_exists(file)
  assert_false(@fs.exists(file))
  let directory = @fsops.join(root, "directory")
  @fs.mkdir(directory)
  try cleanup_file_if_exists(directory) catch {
    _ => assert_true(@fs.exists(directory))
  } noraise {
    _ => fail("file cleanup must not remove a directory")
  }
}
