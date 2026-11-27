///|
async fn cross_device_stat(path : String) -> String {
  let result = @harness.run("/usr/bin/stat", [
    "-c", "%d:%i:%h:%a:%s:%y", "--", path,
  ])
  assert_eq(result.status, 0)
  assert_eq(result.stderr, b"")
  @utf8.decode(result.stdout).trim().to_owned()
}

///|
async fn mv_cross_device_scenario(root : String, work : String) -> Unit {
  // The real CI workspace and Linux tmpfs must be different mount devices.
  let unique = @fs.tmpdir(prefix="cmd-mv-cross-")
  defer @fs.rmdir(unique)
  let target_root = "/dev/shm/" + @path.Path(unique).basename().to_owned()
  @fs.mkdir(target_root, permission=0o700)
  defer @fs.rmdir(target_root, recursive=true)
  let source_device = cross_device_stat(work)
    .split(":")
    .next()
    .unwrap()
    .to_owned()
  let target_device = cross_device_stat(target_root)
    .split(":")
    .next()
    .unwrap()
    .to_owned()
  assert_true(
    source_device != target_device,
    msg="cross-device fixture requires two different st_dev values",
  )
  let records : Array[Json] = []
  for implementation in ["wasm", "gnu"] {
    for backup in [false, true] {
      let label = implementation + (if backup { "-backup" } else { "-plain" })
      let source = work + "/" + label
      let alias_path = work + "/" + label + "-alias"
      let dest = target_root + "/" + label
      @fs.write_file(source, b"source\x00\xff", permission=0o640)
      assert_eq(@harness.run("/usr/bin/ln", [source, alias_path]).status, 0)
      @fs.write_file(dest, b"previous\n", permission=0o600)
      let source_before = cross_device_stat(source)
      let dest_before = cross_device_stat(dest)
      let flags = if backup { ["--no-copy", "-b"] } else { ["--no-copy"] }
      let args = [..flags, source, dest]
      let result = if implementation == "gnu" {
        @harness.run("/usr/bin/mv", args, extra_env={ "LC_ALL": "C" })
      } else {
        @harness.run_command(root, "mv", args, extra_env={ "LC_ALL": "C" })
      }
      let message = @utf8.decode(result.stderr)
      records.push({
        "case": Json(label),
        "status": Json(result.status),
        "stderr": Json(message),
        "source": Json(source_before),
        "destination": Json(dest_before),
      })
      @fs.write_file(work + "/receipts.json", Json(records).stringify())
      assert_eq(result.status, 1)
      assert_eq(result.stdout, b"")
      assert_true(message.contains("Invalid cross-device link"))
      assert_eq(cross_device_stat(source), source_before)
      assert_eq(cross_device_stat(alias_path), source_before)
      assert_eq(@fs.read_file(alias_path).binary(), b"source\x00\xff")
      let saved = if backup { dest + "~" } else { dest }
      assert_eq(cross_device_stat(saved), dest_before)
      assert_eq(@fs.read_file(saved).binary(), b"previous\n")
      assert_false(@fs.exists(if backup { dest } else { dest + "~" }))
    }
  }
}
