///|
priv struct BlockedSortOutput {
  ready : @async.Queue[Unit]
  release : @async.Queue[Unit]
}

///|
impl @io.Writer for BlockedSortOutput with fn write_once(
  self,
  _bytes,
  offset~,
  len~,
) {
  ignore(offset)
  self.ready.put(())
  ignore(self.release.get())
  len
}

///|
async test "cancelled external sort removes real spool directories" {
  @async.with_timeout(5000, () => {
    let root = @fs.tmpdir(prefix="sort-spool-cancel-")
    defer @fs.rmdir(root, recursive=true)
    let parent = root + "/spool"
    @fs.mkdir(parent)
    @fs.write_file(parent + "/keep", "unowned")
    let input = root + "/input"
    @fs.write_file(input, "c\nb\na\n")
    @async.with_task_group(group => {
      let ready : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      let release : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
      defer ignore(release.try_put(()))
      let output : BlockedSortOutput = { ready, release, }
      let task = group.spawn(() => {
        ignore(
          sort_sources(
            [input],
            output,
            b'\n',
            [],
            test_modifiers(),
            None,
            unique=false,
            budget=0,
            fan_in=2,
            temporary_directories=[parent],
          ),
        )
      })
      ignore(ready.get())
      let entries = @fs.readdir(parent)
      assert_true(entries.any(name => name.has_prefix("cli-sort-")))
      task.cancel()
      let cancelled = try {
        task.wait()
        false
      } catch {
        @async.WaitedTaskAlreadyCancelled => true
        error => raise error
      }
      assert_true(cancelled)
    })
    assert_eq(@fs.readdir(parent), ["keep"])
    assert_eq(@fs.read_file(parent + "/keep").text(), "unowned")
    assert_eq(@fs.read_file(input).text(), "c\nb\na\n")
  })
}
