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
    @fsops.copy_path_with_links(
      source,
      @fsops.join(source, "child/copy"),
      true,
      true,
      NeverFollowLinks,
    )
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
  let buffer = FixedArray::make(65536 * 2 + 7, b'\x00')
  for index in 0..<buffer.length() {
    buffer[index] = (index % 256).to_byte()
  }
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  @fs.write_file(source, bytes)
  try
    @fsops.copy_path_with_links(
      source,
      destination,
      false,
      true,
      NeverFollowLinks,
    )
  catch {
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
  assert_eq(@fs.read_file(source).binary(), bytes)
  assert_eq(@fs.read_file(destination).binary(), bytes)
}

///|
async test "copy preflight rejects followed symbolic-link cycles before output" {
  if !@platform.symbolic_link_creation_supported() {
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
async test "numbered backups retain consecutive existing versions" {
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
async test "numbered backups advance past gaps without changing older contents" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-gap")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, ".target")
  @fs.write_file(path, b"current")
  @fs.write_file(path + ".~1~", b"first")
  @fs.write_file(path + ".~3~", b"third")
  for mode in [@fsops.NumberedBackup, @fsops.ExistingBackup] {
    assert_eq(@fsops.select_backup_path(path, mode), Some(path + ".~4~"))
  }
  assert_eq(
    @fsops.backup_destination(path, ExistingBackup),
    Some(path + ".~4~"),
  )
  assert_false(@fs.exists(path))
  assert_false(@fs.exists(path + ".~2~"))
  assert_eq(@fs.read_file(path + ".~1~").binary(), b"first")
  assert_eq(@fs.read_file(path + ".~3~").binary(), b"third")
  assert_eq(@fs.read_file(path + ".~4~").binary(), b"current")
}

///|
async test "backup names require a positive unpadded decimal version" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-names")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "target")
  for suffix in [".~", ".~~", ".~0~", ".~01~", ".~9x~", ".~2~extra", ".~+3~"] {
    @fs.write_file(path + suffix, b"unrelated")
  }
  assert_eq(@fsops.select_backup_path(path, NoBackup), None)
  assert_eq(
    @fsops.select_backup_path(path, NumberedBackup),
    Some(path + ".~1~"),
  )
  assert_eq(@fsops.select_backup_path(path, ExistingBackup), Some(path + "~"))
  @fs.mkdir(path + ".~9~")
  assert_eq(
    @fsops.select_backup_path(path, ExistingBackup),
    Some(path + ".~10~"),
  )
  assert_eq(
    @fsops.select_backup_path(path, SimpleBackup, suffix=".save"),
    Some(path + ".save"),
  )
}

///|
async test "backup versions carry beyond machine integer limits" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-large")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = @fsops.join(root, "target")
  @fs.write_file(path + ".~99999999999999999999~", b"large")
  @fs.write_file(path + ".~9223372036854775807~", b"integer-limit")
  for mode in [@fsops.NumberedBackup, @fsops.ExistingBackup] {
    assert_eq(
      @fsops.select_backup_path(path, mode),
      Some(path + ".~100000000000000000000~"),
    )
  }
}

///|
async test "backup directory scan errors do not become a simple fallback" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-errors")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = root + "/missing/target"
  for mode in [@fsops.NumberedBackup, @fsops.ExistingBackup] {
    try @fsops.select_backup_path(path, mode) catch {
      @os_error.OSError(_) as error => assert_true(error.is_ENOENT())
      error => fail("expected original filesystem error: \{error}")
    } noraise {
      _ => fail("missing directory must not produce a backup name")
    }
  }
}

///|
async test "backup versions follow filesystem aliases and keep distinct names separate" {
  for
    (entry, operand) in [
      ("Destination", "destination"),
      ("caf\u{e9}", "cafe\u{301}"),
      (".\u{c4}hidden", ".\u{e4}hidden"),
    ] {
    let root = @fs.tmpdir(prefix="mooncmd-backup-alias")
    defer @fs.rmdir(root, recursive=true)
    let original = root + "/" + entry
    let path = root + "/" + operand
    @fs.write_file(original, b"old")
    @fs.write_file(original + ".~1~", b"first")
    @fs.write_file(original + ".~3~", b"third")
    @fs.write_file(root + "/unrelated.~8~", b"unrelated")
    // Observe the actual volume instead of assuming case/Unicode normalization.
    let aliases = @fs.exists(path)
    if !aliases {
      @fs.write_file(path, b"distinct")
    }
    let expected = path + (if aliases { ".~4~" } else { ".~1~" })
    for control in [@fsops.NumberedBackup, @fsops.ExistingBackup] {
      assert_eq(
        @fsops.select_backup_path(path, control),
        Some(
          if !aliases && control == @fsops.ExistingBackup {
            path + "~"
          } else {
            expected
          },
        ),
      )
    }
    assert_eq(@fsops.backup_destination(path, NumberedBackup), Some(expected))
    assert_false(@fs.exists(path))
    assert_eq(
      @fs.read_file(expected).binary(),
      if aliases {
        b"old"
      } else {
        b"distinct"
      },
    )
    assert_eq(@fs.read_file(original + ".~1~").binary(), b"first")
    assert_eq(@fs.read_file(original + ".~3~").binary(), b"third")
    assert_eq(@fs.read_file(root + "/unrelated.~8~").binary(), b"unrelated")
    if !aliases {
      assert_eq(@fs.read_file(original).binary(), b"old")
    }
  }
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
