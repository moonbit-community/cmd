///|
async test "mv cancellation after rename preserves the moved file and backup" {
  @async.with_timeout(5000, () => {
    let root = @fs.tmpdir(prefix="mooncmd-mv-committed-cancel-")
    defer @fs.rmdir(root, recursive=true)
    let source = @fsops.join(root, "source")
    let target = @fsops.join(root, "target")
    @fs.write_file(source, b"new")
    @fs.write_file(target, b"original")
    @async.with_task_group(group => {
      let ready : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      let release : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      defer ignore(release.try_put(()))
      let options = { ..link_move_options(), backup: @fsops.SimpleBackup, }
      let task = group.spawn(() => {
        move_one(source, target, options, rename=(source, target, replace) => {
          @fs.rename(source, target, replace~)
          @async.protect_from_cancel(() => {
            ready.put(())
            ignore(release.get())
          })
        })
      })
      ignore(ready.get())
      task.cancel()
      release.put(())
      let cancelled = try {
        ignore(task.wait())
        false
      } catch {
        @async.WaitedTaskAlreadyCancelled => true
        error => raise error
      }
      assert_true(cancelled)
    })
    assert_false(@fs.exists(source))
    assert_eq(@fs.read_file(target).binary(), b"new")
    assert_eq(@fs.read_file(target + "~").binary(), b"original")
  })
}
