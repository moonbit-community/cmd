///|
test "timestamp comparison keeps nanosecond ordering" {
  let earlier : @fsops.FileTimestamp = { seconds: 10L, nanoseconds: 999, }
  let later : @fsops.FileTimestamp = { seconds: 11L, nanoseconds: 0, }
  assert_eq(@fsops.compare_timestamps(earlier, later), -1)
  assert_eq(@fsops.compare_timestamps(later, earlier), 1)
  assert_eq(@fsops.compare_timestamps(earlier, earlier), 0)
}

///|
test "update modes and backup controls are explicit" {
  let source : @fsops.FileTimestamp = { seconds: 2L, nanoseconds: 1, }
  let target : @fsops.FileTimestamp = { seconds: 2L, nanoseconds: 0, }
  assert_eq(
    @fsops.overwrite_decision(UpdateOlder, source, Some(target)),
    ReplaceDestination,
  )
  assert_eq(
    @fsops.overwrite_decision(UpdateNone, source, Some(target)),
    SkipDestination,
  )
  assert_eq(@fsops.parse_backup_control("numbered"), NumberedBackup)
  assert_eq(@fsops.parse_update_mode("none-fail"), UpdateNoneFail)
}

///|
async test "an unrelated long backup version cannot invalidate a valid target name" {
  let root = @fs.tmpdir(prefix="mooncmd-backup-long")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/" + String::from_array(Array::make(140, 'd'))
  let number = String::from_array(Array::make(120, '9'))
  let unrelated = root + "/other.~" + number + "~"
  @fs.write_file(path, b"old")
  @fs.write_file(unrelated, b"unrelated")
  assert_eq(
    @fsops.backup_destination(path, NumberedBackup),
    Some(path + ".~1~"),
  )
  assert_false(@fs.exists(path))
  assert_eq(@fs.read_file(path + ".~1~").binary(), b"old")
  assert_eq(@fs.read_file(unrelated).binary(), b"unrelated")
}

///|
async test "recursive removal does not follow a symbolic link" {
  if !@platform.symbolic_link_creation_supported() {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-fsops-link")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let target = @fsops.join(root, "target")
  let link = @fsops.join(root, "link")
  @fs.mkdir(target)
  @fs.write_file(@fsops.join(target, "kept"), b"safe")
  @fs.symlink(link, target~)
  @fsops.remove_path(link, true)
  assert_true(@fs.exists(@fsops.join(target, "kept")))
  assert_false(@fs.exists(link))
}

///|
async test "numbered destinations atomically create the first missing sibling" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-numbered")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "result")
  let (first_path, first) = @fsops.open_unique_numbered_output(path)
  assert_eq(first_path, path)
  first.write(b"zero")
  first.close()
  @fs.write_file(path + ".1", b"one")
  let (third_path, third) = @fsops.open_unique_numbered_output(path)
  assert_eq(third_path, path + ".2")
  third.close()
}

///|
async test "output modes preserve create truncate and append semantics" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-output")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "output")
  let created = @fsops.open_output(path, CreateNew)
  created.write(b"first")
  created.close()
  try @fsops.open_output(path, CreateNew) catch {
    _ => ()
  } noraise {
    file => {
      file.close()
      fail("CreateNew must reject an existing path")
    }
  }
  let appended = @fsops.open_output(path, AppendOrCreate)
  appended.write(b"+second")
  appended.close()
  assert_eq(@fs.read_file(path).binary(), b"first+second")
  let truncated = @fsops.open_output(path, CreateOrTruncate)
  truncated.write(b"last")
  truncated.close()
  assert_eq(@fs.read_file(path).binary(), b"last")
}

///|
async test "temporary cleanup is idempotent and refuses directories" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cleanup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fsops.join(root, "file")
  @fs.write_file(file, b"temporary")
  @fsops.cleanup_file_if_exists(file)
  @fsops.cleanup_file_if_exists(file)
  assert_false(@fs.exists(file))
  let directory = @fsops.join(root, "directory")
  @fs.mkdir(directory)
  try @fsops.cleanup_file_if_exists(directory) catch {
    _ => assert_true(@fs.exists(directory))
  } noraise {
    _ => fail("file cleanup must not remove a directory")
  }
}
