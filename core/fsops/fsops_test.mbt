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

///|
async test "numbered destinations atomically create the first missing sibling" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-numbered")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = join(root, "result")
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
async test "output modes preserve create truncate and append semantics" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-output")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = join(root, "output")
  let created = open_output(path, CreateNew)
  created.write(b"first")
  created.close()
  try open_output(path, CreateNew) catch {
    _ => ()
  } noraise {
    file => {
      file.close()
      fail("CreateNew must reject an existing path")
    }
  }
  let appended = open_output(path, AppendOrCreate)
  appended.write(b"+second")
  appended.close()
  assert_eq(@fs.read_file(path).binary(), b"first+second")
  let truncated = open_output(path, CreateOrTruncate)
  truncated.write(b"last")
  truncated.close()
  assert_eq(@fs.read_file(path).binary(), b"last")
}

///|
async test "metadata and atomic commit expose completed files only" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-commit")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let temporary = join(root, "download.part")
  let destination = join(root, "download")
  @fs.write_file(temporary, b"payload")
  guard metadata_if_exists(temporary) is Some(metadata) else {
    fail("temporary file metadata is missing")
  }
  assert_eq(metadata.kind, @fs.FileKind::Regular)
  assert_eq(metadata.size, Some(7L))
  commit_temporary_file(temporary, destination)
  assert_false(@fs.exists(temporary))
  assert_eq(@fs.read_file(destination).binary(), b"payload")
  cleanup_file_if_exists(destination)
  cleanup_file_if_exists(destination)
  assert_false(@fs.exists(destination))
}

///|
async test "failed atomic commit removes temporary file and preserves target" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-commit-failure")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let temporary = join(root, "download.part")
  let destination = join(root, "download")
  @fs.write_file(temporary, b"new")
  @fs.write_file(destination, b"original")
  try commit_temporary_file(temporary, destination, replace=false) catch {
    _ => {
      assert_false(@fs.exists(temporary))
      assert_eq(@fs.read_file(destination).binary(), b"original")
    }
  } noraise {
    _ => fail("non-replacing commit must reject an existing destination")
  }
}

///|
async test "metadata lookup distinguishes missing paths and symbolic links" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-metadata")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  assert_eq(metadata_if_exists(join(root, "missing")), None)
  if !@platform.symbolic_links_supported() {
    return
  }
  let target = join(root, "target")
  let link = join(root, "link")
  @fs.write_file(target, b"payload")
  @fs.symlink(link, target~)
  guard metadata_if_exists(link) is Some(link_metadata) else {
    fail("symbolic-link metadata is missing")
  }
  assert_eq(link_metadata.kind, @fs.FileKind::SymLink)
  guard metadata_if_exists(link, follow_symlink=true) is Some(target_metadata) else {
    fail("followed target metadata is missing")
  }
  assert_eq(target_metadata.kind, @fs.FileKind::Regular)
  assert_eq(target_metadata.size, Some(7L))
}

///|
async test "temporary cleanup refuses directories" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cleanup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let directory = join(root, "directory")
  @fs.mkdir(directory)
  try cleanup_file_if_exists(directory) catch {
    _ => assert_true(@fs.exists(directory))
  } noraise {
    _ => fail("file cleanup must not remove a directory")
  }
}
