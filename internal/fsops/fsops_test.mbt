///|
test "deletion path protection rejects roots and working-directory ancestors" {
  inspect(protects_working_directory("."), content="true")
  inspect(protects_working_directory("./"), content="true")
  inspect(protects_working_directory(".."), content="true")
  inspect(protects_working_directory("../outside"), content="false")
  inspect(protects_working_directory("/"), content="true")
}

///|
test "deletion path protection permits ordinary descendants" {
  inspect(protects_working_directory("file"), content="false")
  inspect(protects_working_directory("directory/file"), content="false")
  inspect(protects_working_directory("./directory"), content="false")
}

///|
async test "recursive copy rejects a destination inside its source" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = join(root, "source")
  @fs.mkdir(join(source, "child"), recursive=true)
  @fs.write_file(join(source, "file"), b"content")
  try copy_path(source, join(source, "child/copy"), true, true) catch {
    _ => assert_false(@fs.exists(join(source, "child/copy")))
  } noraise {
    _ => fail("expected nested-destination error")
  }
}

///|
async test "recursive removal does not follow a symbolic link" {
  if !@platform.symbolic_links_supported() {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-fsops-link")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let target = join(root, "target")
  let link = join(root, "link")
  @fs.mkdir(target)
  @fs.write_file(join(target, "kept"), b"safe")
  @fs.symlink(link, target~)
  remove_path(link, true)
  assert_true(@fs.exists(join(target, "kept")))
  assert_false(@fs.exists(link))
}
