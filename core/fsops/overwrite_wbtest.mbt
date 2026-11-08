///|
async test "a numbered backup appearing after selection is never overwritten" {
  for control in [BackupControl::NumberedBackup, ExistingBackup] {
    let root = @fs.tmpdir(prefix="mooncmd-backup-collision")
    defer @fs.rmdir(root, recursive=true)
    let path = root + "/target"
    @fs.write_file(path, b"current")
    @fs.write_file(path + ".~1~", b"first")
    let mut reached_rename = false
    try
      backup_entry(path, control, rename=(source, destination, replace) => {
        reached_rename = true
        assert_eq(source, path)
        assert_eq(destination, path + ".~2~")
        assert_false(replace)
        @fs.write_file(destination, b"competing backup")
        @fs.rename(source, destination, replace~)
      })
    catch {
      @os_error.OSError(_) as error => assert_true(error.is_EEXIST())
      error => raise error
    } noraise {
      _ => fail("numbered backup collision must fail without replacement")
    }
    assert_true(reached_rename)
    assert_eq(@fs.read_file(path).binary(), b"current")
    assert_eq(@fs.read_file(path + ".~1~").binary(), b"first")
    assert_eq(@fs.read_file(path + ".~2~").binary(), b"competing backup")
  }
}

///|
async test "simple suffix spelling does not select numbered replacement policy" {
  let root = @fs.tmpdir(prefix="mooncmd-backup-simple-policy")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/target"
  @fs.write_file(path, b"current")
  assert_eq(
    backup_entry(path, ExistingBackup, suffix=".~2~", rename=(
      source,
      destination,
      replace,
    ) => {
      assert_eq(destination, path + ".~2~")
      assert_true(replace)
      @fs.write_file(destination, b"previous simple backup")
      @fs.rename(source, destination, replace~)
    }),
    Some(path + ".~2~"),
  )
  assert_false(@fs.exists(path))
  assert_eq(@fs.read_file(path + ".~2~").binary(), b"current")
}

///|
async test "a real oversized alias probe uses a supported host error code" {
  let root = @fs.tmpdir(prefix="mooncmd-backup-code")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/" + String::from_array(Array::make(140, 'd'))
  let number = String::from_array(Array::make(120, '9'))
  try @fs.kind(path + ".~" + number + "~", follow_symlink=false) catch {
    @os_error.OSError(code, ..) as error => {
      assert_true(
        code == name_too_long_code() || error.is_ENOENT(),
        msg="unexpected oversized probe error: \{code}",
      )
      println("Oversized backup-name probe OS code: \{code}")
    }
    error => raise error
  } noraise {
    _ => fail("the generated oversized candidate must not exist")
  }
  assert_false(backup_alias_exists(path, number))
}
