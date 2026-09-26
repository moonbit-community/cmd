///|
test "deletion path protection rejects roots and working-directory ancestors" {
  inspect(@fsops.protects_working_directory("."), content="true")
  inspect(@fsops.protects_working_directory("./"), content="true")
  inspect(@fsops.protects_working_directory(".."), content="true")
  inspect(@fsops.protects_working_directory("../outside"), content="false")
  inspect(@fsops.protects_working_directory("/"), content="true")
}

///|
test "deletion path protection permits ordinary descendants" {
  inspect(@fsops.protects_working_directory("file"), content="false")
  inspect(@fsops.protects_working_directory("directory/file"), content="false")
  inspect(@fsops.protects_working_directory("./directory"), content="false")
}

///|
test "rm operand protection follows command flags and final components" {
  assert_true(@fsops.protects_removal_operand("."))
  assert_true(@fsops.protects_removal_operand("dir/../"))
  assert_true(@fsops.protects_removal_operand("/"))
  assert_false(@fsops.protects_removal_operand("/", preserve_root=false))
  assert_true(@fsops.protects_removal_operand("dir/.", preserve_root=false))
  assert_false(@fsops.protects_removal_operand("/named/working/directory"))
  if @platform.is_windows() {
    assert_true(@fsops.protects_removal_operand("dir\\..\\"))
    assert_true(
      @fsops.protects_removal_operand("C:\\dir\\.\\", preserve_root=false),
    )
  } else {
    assert_false(@fsops.protects_removal_operand("dir\\..\\"))
  }
}

///|
test "timestamp comparison keeps nanosecond ordering" {
  let earlier : @fsops.FileTimestamp = { seconds: 10L, nanoseconds: 999, }
  let later : @fsops.FileTimestamp = { seconds: 11L, nanoseconds: 0, }
  assert_eq(@fsops.compare_timestamps(earlier, later), -1)
  assert_eq(@fsops.compare_timestamps(later, earlier), 1)
  assert_eq(@fsops.compare_timestamps(earlier, earlier), 0)
}

///|
test "timestamp age buckets account for subsecond boundaries" {
  let now : @fsops.FileTimestamp = { seconds: 120L, nanoseconds: 0, }
  let previous : @fsops.FileTimestamp = { seconds: 60L, nanoseconds: 1, }
  assert_eq(@fsops.timestamp_age_bucket(now, previous, 60L), 0L)
  assert_eq(
    @fsops.timestamp_age_bucket(now, { seconds: 0L, nanoseconds: 0, }, 60L),
    2L,
  )
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
async test "recursive copy rejects a destination inside its source" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  @fs.mkdir(@fsops.join(source, "child"), recursive=true)
  @fs.write_file(@fsops.join(source, "file"), b"content")
  try
    @fsops.copy_path(source, @fsops.join(source, "child/copy"), true, true)
  catch {
    _ => assert_false(@fs.exists(@fsops.join(source, "child/copy")))
  } noraise {
    _ => fail("expected nested-destination error")
  }
}

///|
async test "copy rejects unsafe overwrite without changing either file" {
  let root = @fs.tmpdir(prefix="mooncmd-copy-overwrite")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.write_file(source, b"source bytes")
  @fs.write_file(destination, b"destination bytes")
  try
    @fsops.copy_path_with_links(
      source,
      destination,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    )
  catch {
    _ => {
      assert_eq(@fs.read_file(source).binary(), b"source bytes")
      assert_eq(@fs.read_file(destination).binary(), b"destination bytes")
    }
  } noraise {
    _ => fail("unsafe overwrite succeeded")
  }
  try
    @fsops.copy_path_with_links(
      source,
      source,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    )
  catch {
    _ => assert_eq(@fs.read_file(source).binary(), b"source bytes")
  } noraise {
    _ => fail("same-file overwrite succeeded")
  }
}

///|
async test "copy supports explicit no-preserve mode only for new files" {
  let root = @fs.tmpdir(prefix="mooncmd-copy-new")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.write_file(source, b"copy bytes")
  try @fsops.copy_path(source, destination, false, true) catch {
    _ => assert_false(@fs.exists(destination))
  } noraise {
    _ => fail("default copy cannot preserve source mode")
  }
  ignore(
    @fsops.copy_path_with_links(
      source,
      destination,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    ),
  )
  assert_eq(@fs.read_file(destination).binary(), b"copy bytes")
}

///|
async test "copy preflight rejects followed symbolic-link cycles before output" {
  if !@platform.symbolic_links_supported() {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cycle")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.mkdir(source)
  @fs.write_file(@fsops.join(source, "file"), b"content")
  @fs.symlink(@fsops.join(source, "loop"), target=source)
  try
    @fsops.preflight_copy_path(source, destination, true, FollowAllLinks)
  catch {
    _ => assert_false(@fs.exists(destination))
  } noraise {
    _ => fail("expected symbolic-link cycle error")
  }
}

///|
async test "numbered backups select the first available GNU sibling" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "target")
  @fs.write_file(path, b"current")
  @fs.write_file(path + ".~1~", b"first")
  assert_eq(
    @fsops.select_backup_path(path, NumberedBackup),
    Some(path + ".~2~"),
  )
  assert_eq(
    @fsops.backup_destination(path, NumberedBackup),
    Some(path + ".~2~"),
  )
  assert_false(@fs.exists(path))
  assert_eq(@fs.read_file(path + ".~2~").binary(), b"current")
}

///|
async test "recursive removal does not follow a symbolic link" {
  if !@platform.symbolic_links_supported() {
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
async test "metadata and atomic commit expose completed files only" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-commit")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let temporary = @fsops.join(root, "download.part")
  let destination = @fsops.join(root, "download")
  @fs.write_file(temporary, b"payload")
  guard @fsops.metadata_if_exists(temporary) is Some(metadata) else {
    fail("temporary file metadata is missing")
  }
  assert_eq(metadata.kind, @fs.FileKind::Regular)
  assert_eq(metadata.size, Some(7L))
  @fsops.commit_temporary_file(temporary, destination)
  assert_false(@fs.exists(temporary))
  assert_eq(@fs.read_file(destination).binary(), b"payload")
  @fsops.cleanup_file_if_exists(destination)
  @fsops.cleanup_file_if_exists(destination)
  assert_false(@fs.exists(destination))
}

///|
async test "failed atomic commit removes temporary file and preserves target" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-commit-failure")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let temporary = @fsops.join(root, "download.part")
  let destination = @fsops.join(root, "download")
  @fs.write_file(temporary, b"new")
  @fs.write_file(destination, b"original")
  try
    @fsops.commit_temporary_file(temporary, destination, replace=false)
  catch {
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
  assert_eq(@fsops.metadata_if_exists(@fsops.join(root, "missing")), None)
  if !@platform.symbolic_links_supported() {
    return
  }
  let target = @fsops.join(root, "target")
  let link = @fsops.join(root, "link")
  @fs.write_file(target, b"payload")
  @fs.symlink(link, target~)
  guard @fsops.metadata_if_exists(link) is Some(link_metadata) else {
    fail("symbolic-link metadata is missing")
  }
  assert_eq(link_metadata.kind, @fs.FileKind::SymLink)
  guard @fsops.metadata_if_exists(link, follow_symlink=true)
    is Some(target_metadata) else {
    fail("followed target metadata is missing")
  }
  assert_eq(target_metadata.kind, @fs.FileKind::Regular)
  assert_eq(target_metadata.size, Some(7L))
}

///|
async test "temporary cleanup refuses directories" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cleanup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let directory = @fsops.join(root, "directory")
  @fs.mkdir(directory)
  try @fsops.cleanup_file_if_exists(directory) catch {
    _ => assert_true(@fs.exists(directory))
  } noraise {
    _ => fail("file cleanup must not remove a directory")
  }
}
