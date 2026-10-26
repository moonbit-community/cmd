///|
async test "snapshot can observe metadata without loading large file contents" {
  let root = @fs.tmpdir(prefix="mooncmd-snapshot-content-")
  defer @fs.rmdir(root, recursive=true)
  let file = @fs.create(root + "/large")
  file.write_at(b"x", position=67108863L)
  file.close()
  let entries = snapshot(root, content=false)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].kind, "file")
  assert_eq(entries[0].content, b"")
  assert_eq(@fs.file_size(root + "/large"), 67108864L)
  @fs.write_file(root + "/large", b"small")
  assert_eq(snapshot(root)[0].content, b"small")
}

///|
async test "rejection detects same-content replacement of an existing file" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/sh", "/bin/mv", "/usr/bin/stat"])
  let root = @fs.tmpdir(prefix="mooncmd-rejection-identity-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  // The observer replaces the file with preallocated identical bytes and then
  // rejects the operation. Only the preserved device/inode detects the mutation.
  @fs.write_file(root + "/replacement", b"preserved bytes")
  let fixture : Case = @json.from_json({
    "id": "replacement-before-rejection",
    "command": "replace-reject",
    "args": [
      "-c",
      "/bin/mv \"$1\" \"$2\" || exit 97; printf 'unsupported operation\\n' >&2; exit 1",
      "identity-observer",
      Json(root + "/replacement"),
      "${WORK}/original",
    ],
    "files": [{ "path": "original", "content_text": "preserved bytes" }],
    "environment": {},
    "expected_status": 1,
    "comparison": "boundary",
    "expected_rejection": "unsupported operation",
    "expected_stdout_text": "",
    "expected_stderr_text": "unsupported operation\n",
    "observe": ["identity"],
    "normalizations": [],
  })
  let report = execute_contract(
    fixture,
    root,
    false,
    root + "/reports",
    observer="/bin/sh",
  )
  assert_eq(report.result, "fail", msg=report.detail)
  assert_eq(report.stage, "assertion")
  assert_true(report.detail.contains("rejected operation changed fixture"))
  guard report.evidence is Some(evidence) else {
    fail("the rejected mutation must retain its fixture")
  }
  assert_eq(
    @fs.read_file(evidence + "/work/original").binary(),
    b"preserved bytes",
  )
  assert_false(@fs.exists(root + "/replacement"))
}

///|
async test "snapshot timestamps separate completed baseline reads from final observations" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/ln", "/usr/bin/touch", "/usr/bin/true"])
  let root = @fs.tmpdir(prefix="mooncmd-snapshot-atime-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = root + "/source"
  let linked_path = root + "/alias"
  @fs.write_file(source, b"timestamp fixture")
  assert_eq(run("/bin/ln", [source, linked_path]).status, 0)
  // A fixed observer sets an old access time so the content read has a
  // measurable effect. The filesystem must actually expose that effect.
  assert_eq(
    run("/usr/bin/touch", ["-a", "-t", "200001010000.00", source]).status,
    0,
  )
  let (seconds, nanos) = @fs.atime(source)
  let before_read = "\{seconds}:\{nanos}"
  let final_observation = snapshot(root, observe=["atime"])
  assert_eq(final_observation.length(), 2)
  for entry in final_observation {
    assert_eq(entry.content, b"timestamp fixture")
    assert_eq(entry.metadata["atime"], before_read)
  }
  ignore(@fs.read_file(source, sync_timestamp=true))
  let (seconds, nanos) = @fs.atime(source)
  assert_true(
    "\{seconds}:\{nanos}" != before_read,
    msg="fixture precondition: filesystem must expose content-read atime changes",
  )
  let baseline = snapshot(root, observe=["atime"], baseline=true)
  let (seconds, nanos) = @fs.atime(source)
  for entry in baseline {
    assert_eq(entry.metadata["atime"], "\{seconds}:\{nanos}")
  }
  assert_eq(run("/usr/bin/true", []).status, 0)
  assert_true(snapshots_equal(baseline, snapshot(root, observe=["atime"])))
}
