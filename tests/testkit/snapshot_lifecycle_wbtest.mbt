///|
async test "rejection detects same-content replacement of an existing file" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/sh", "/bin/mv", "/usr/bin/stat"])
  let root = @fs.tmpdir(prefix="mooncmd-rejection-identity-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/cli/replace-reject", recursive=true)
  @fs.symlink(root + "/cli/replace-reject/replace-reject.exe", target="/bin/sh")
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
  let report = execute_contract(fixture, root, false, root + "/reports")
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
