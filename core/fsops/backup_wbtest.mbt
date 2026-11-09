///|
async test "numbered backups retain consecutive existing versions" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = join(root, "target")
  @fs.write_file(path, b"current")
  @fs.write_file(path + ".~1~", b"first")
  assert_eq(
    select_backup(path, NumberedBackup).map(backup => backup.path),
    Some(path + ".~2~"),
  )
  assert_eq(backup_destination(path, NumberedBackup), Some(path + ".~2~"))
  assert_false(@fs.exists(path))
  assert_eq(@fs.read_file(path + ".~2~").binary(), b"current")
}

///|
async test "numbered backups advance past gaps without changing older contents" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-gap")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = join(root, ".target")
  @fs.write_file(path, b"current")
  @fs.write_file(path + ".~1~", b"first")
  @fs.write_file(path + ".~3~", b"third")
  for mode in [NumberedBackup, ExistingBackup] {
    assert_eq(
      select_backup(path, mode).map(backup => backup.path),
      Some(path + ".~4~"),
    )
  }
  assert_eq(backup_destination(path, ExistingBackup), Some(path + ".~4~"))
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
  let path = join(root, "target")
  for suffix in [".~", ".~~", ".~0~", ".~01~", ".~9x~", ".~2~extra", ".~+3~"] {
    @fs.write_file(path + suffix, b"unrelated")
  }
  assert_eq(select_backup(path, NoBackup).map(backup => backup.path), None)
  assert_eq(
    select_backup(path, NumberedBackup).map(backup => backup.path),
    Some(path + ".~1~"),
  )
  assert_eq(
    select_backup(path, ExistingBackup).map(backup => backup.path),
    Some(path + "~"),
  )
  @fs.mkdir(path + ".~9~")
  assert_eq(
    select_backup(path, ExistingBackup).map(backup => backup.path),
    Some(path + ".~10~"),
  )
  assert_eq(
    select_backup(path, SimpleBackup, suffix=".save").map(backup => backup.path),
    Some(path + ".save"),
  )
}

///|
async test "backup versions carry beyond machine integer limits" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-large")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = join(root, "target")
  @fs.write_file(path + ".~99999999999999999999~", b"large")
  @fs.write_file(path + ".~9223372036854775807~", b"integer-limit")
  for mode in [NumberedBackup, ExistingBackup] {
    assert_eq(
      select_backup(path, mode).map(backup => backup.path),
      Some(path + ".~100000000000000000000~"),
    )
  }
}

///|
async test "backup directory scan errors do not become a simple fallback" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops-backup-errors")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let path = root + "/missing/target"
  for mode in [NumberedBackup, ExistingBackup] {
    try select_backup(path, mode).map(backup => backup.path) catch {
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
    for control in [NumberedBackup, ExistingBackup] {
      assert_eq(
        select_backup(path, control).map(backup => backup.path),
        Some(
          if !aliases && control == ExistingBackup {
            path + "~"
          } else {
            expected
          },
        ),
      )
    }
    assert_eq(backup_destination(path, NumberedBackup), Some(expected))
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
