///|
async test "creation failure restores real backup contents and preserves the primary error" {
  let root = @fs.tmpdir(prefix="ln-recovery-")
  defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
  let destination = root + "/destination"
  for control in [@fsops.SimpleBackup, @fsops.NumberedBackup] {
    @fs.write_file(destination, b"original destination")
    let backup = @fsops.backup_destination(destination, control).unwrap()
    let mut created = false
    try
      create_symlink(destination, "target", Some(backup), create=(path, target) => {
        created = true
        assert_eq(path, destination)
        assert_eq(target, "target")
        assert_true(@fsops.kind_if_exists(destination) is None)
        assert_eq(@fs.read_file(backup).binary(), b"original destination")
        raise @fsops.FsOpError("injected creation failure")
      })
    catch {
      @fsops.FsOpError(message) =>
        assert_eq(message, "injected creation failure")
      error => raise error
    } noraise {
      _ => fail("creation must fail")
    }
    assert_true(created)
    assert_eq(@fs.read_file(destination).binary(), b"original destination")
    assert_true(@fsops.kind_if_exists(backup) is None)
  }
}

///|
async test "creation and recovery errors retain both diagnostics and actual path state" {
  let root = @fs.tmpdir(prefix="ln-recovery-error-")
  defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
  let destination = root + "/destination"
  for restored_before_error in [false, true] {
    @fs.write_file(destination, b"original destination")
    let backup = @fsops.backup_destination(destination, @fsops.NumberedBackup).unwrap()
    let mut restored = false
    try
      create_symlink(
        destination,
        "target",
        Some(backup),
        create=(_, _) => raise @fsops.FsOpError("injected creation failure"),
        restore=(path, saved) => {
          restored = true
          assert_eq(path, destination)
          assert_eq(saved, backup)
          assert_true(@fsops.kind_if_exists(destination) is None)
          assert_eq(@fs.read_file(backup).binary(), b"original destination")
          if restored_before_error {
            @fsops.restore_backup(path, saved)
          }
          raise @fsops.FsOpError("injected recovery failure")
        },
      )
    catch {
      @fsops.FsOpError(message) =>
        assert_eq(
          message,
          "injected creation failure; cannot restore '\{destination}' from backup '\{backup}': injected recovery failure",
        )
      error => raise error
    } noraise {
      _ => fail("creation must fail")
    }
    assert_true(restored)
    if restored_before_error {
      assert_eq(@fs.read_file(destination).binary(), b"original destination")
      assert_true(@fsops.kind_if_exists(backup) is None)
    } else {
      assert_true(@fsops.kind_if_exists(destination) is None)
      assert_eq(@fs.read_file(backup).binary(), b"original destination")
    }
  }
}

///|
async test "creation without a backup never invokes recovery" {
  let mut recovery_calls = 0
  try
    create_symlink(
      "unused-destination",
      "unused-target",
      None,
      create=(_, _) => raise @fsops.FsOpError("injected creation failure"),
      restore=(_, _) => recovery_calls += 1,
    )
  catch {
    @fsops.FsOpError(message) => assert_eq(message, "injected creation failure")
    error => raise error
  } noraise {
    _ => fail("creation must fail")
  }
  assert_eq(recovery_calls, 0)
}

///|
async test "cancellation after committed creation preserves destination and backup" {
  @async.with_timeout(5000, () => {
    let root = @fs.tmpdir(prefix="ln-committed-cancel-")
    defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
    let destination = root + "/destination"
    let target = root + "/target"
    @fs.write_file(target, b"target contents")
    @fs.write_file(destination, b"original destination")
    let backup = @fsops.backup_destination(destination, @fsops.SimpleBackup).unwrap()
    @async.with_task_group(group => {
      let ready : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      let release : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      defer ignore(release.try_put(()))
      let task = group.spawn(() => {
        create_symlink(destination, target, Some(backup), create=(path, target) => {
          if @platform.symbolic_link_creation_supported() {
            symlink_entry(path, target)
          } else {
            // Windows exercises cancellation ownership with an injected file commit.
            @fs.write_file(path, b"committed entry")
          }
          @async.protect_from_cancel(() => {
            ready.put(())
            ignore(release.get())
          })
          @async.sleep(1)
        })
      })
      ignore(ready.get())
      task.cancel()
      release.put(())
      try ignore(task.wait()) catch {
        @async.WaitedTaskAlreadyCancelled => ()
        error => raise error
      } noraise {
        _ => fail("task must be cancelled")
      }
    })
    if @platform.symbolic_link_creation_supported() {
      assert_true(@fs.kind(destination, follow_symlink=false) is SymLink)
      assert_eq(@fs.read_file(destination).binary(), b"target contents")
    } else {
      assert_eq(@fs.read_file(destination).binary(), b"committed entry")
    }
    assert_eq(@fs.read_file(backup).binary(), b"original destination")
    assert_eq(@fs.read_file(target).binary(), b"target contents")
  })
}
