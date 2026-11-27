///|
pub async fn check_tail_rotation(
  program : String,
  prefix : Array[String],
  work : String,
) -> Unit {
  let log = work + "/log"
  let moved = work + "/rotated"
  @fs.write_file(log, b"skipped\nready\n")
  @async.with_task_group(group => {
    let (output, stdout) = @process.read_from_process()
    defer output.close()
    let (errors, stderr) = @process.read_from_process()
    defer errors.close()
    let child = @harness.spawn(
      group,
      program,
      [..prefix, "-F", "-n1", "-s0.02", "log"],
      cwd=work,
      stdout~,
      stderr~,
      extra_env=@harness.controlled_environment(Map([])),
      cancel_handler=@process.hard_cancel(),
    )
    defer child.cancel()
    async fn record(expected : String) {
      assert_eq(
        @async.with_timeout(5000, () => output.read_until("\n")),
        Some(expected),
      )
    }
    async fn diagnostic(part : String) {
      let line = @async.with_timeout(5000, () => errors.read_until("\n"))
      assert_true(
        line is Some(value) && value.contains(part),
        msg="expected \{part}, got " + line.unwrap_or("end of stream"),
      )
    }
    record("ready")
    // Switch the name to a different directory entry for the same inode.
    let link = @harness.run("ln", [log, work + "/alias"])
    assert_eq(link.status, 0)
    @fs.symlink(work + "/next", target="alias")
    @fs.rename(work + "/next", log, replace=true)
    @fs.write_file(
      log,
      b"alias append\n",
      append=true,
      create_mode=OpenExisting,
    )
    record("alias append")
    @fs.write_file(work + "/next", b"replacement one\nreplacement two\n")
    @fs.rename(work + "/next", log, replace=true)
    diagnostic("has been replaced")
    record("replacement one")
    record("replacement two")
    @fs.rename(log, moved)
    diagnostic("has become inaccessible")
    @fs.write_file(
      moved,
      b"old descriptor only\n",
      append=true,
      create_mode=OpenExisting,
    )
    @fs.write_file(log, b"reappeared one\nreappeared two\n")
    diagnostic("has appeared")
    record("reappeared one")
    record("reappeared two")
    @fs.write_file(log, b"short\n")
    diagnostic("file truncated")
    record("short")
    child.cancel()
    ignore(child.wait())
    assert_eq(output.read_all().binary(), b"")
    assert_eq(errors.read_all().binary(), b"")
  })
  @async.with_task_group(group => {
    let (output, stdout) = @process.read_from_process()
    defer output.close()
    let (errors, stderr) = @process.read_from_process()
    defer errors.close()
    let child = @harness.spawn(
      group,
      program,
      [..prefix, "-F", "-n0", "-s0.02", "absent"],
      cwd=work,
      stdout~,
      stderr~,
      extra_env=@harness.controlled_environment(Map([])),
      cancel_handler=@process.hard_cancel(),
    )
    defer child.cancel()
    assert_true(
      @async.with_timeout(5000, () => errors.read_until("\n")) is Some(line) &&
      line.contains("cannot open"),
    )
    @fs.write_file(work + "/absent", b"first\nsecond\n")
    assert_true(
      @async.with_timeout(5000, () => errors.read_until("\n")) is Some(line) &&
      line.contains("has appeared"),
    )
    assert_eq(
      @async.with_timeout(5000, () => output.read_until("\n")),
      Some("first"),
    )
    assert_eq(
      @async.with_timeout(5000, () => output.read_until("\n")),
      Some("second"),
    )
    child.cancel()
    ignore(child.wait())
    assert_eq(output.read_all().binary(), b"")
    assert_eq(errors.read_all().binary(), b"")
  })
}
