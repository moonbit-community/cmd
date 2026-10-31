///|
async test "output read failure propagates after direct-child cleanup" {
  if host_platform() == "windows" {
    return
  }
  let pid = Ref("")
  try
    run_with_deadline(
      "/bin/sh",
      ["-c", "printf '%s\\n' \"$$\"; exec sleep 30"],
      2000,
      read_stream=reader => {
        let bytes = reader.read_some()
        if bytes is Some(bytes) {
          pid.val = @utf8.decode(bytes).trim().to_owned()
          fail("injected output read failure")
        }
        bytes
      },
    )
  catch {
    error =>
      assert_true(error.to_string().contains("injected output read failure"))
  } noraise {
    _ => fail("output read failure reported success")
  }
  assert_true(@string.parse_int(pid.val) > 1)
  assert_true(run("/bin/kill", ["-0", pid.val]).status != 0)
}

///|
async test "missing product artifact and unavailable report destination fail closed" {
  let root = @fs.tmpdir(prefix="mooncmd-failure-injection-")
  defer @fs.rmdir(root, recursive=true)
  let fixture : Case = @json.from_json({
    "id": "missing-product",
    "command": "cat",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
  })
  let report = execute_contract(
    fixture,
    root + "/missing",
    true,
    root + "/cases",
  )
  assert_false(report.semantic_pass())
  assert_true(report.result == "fail" || report.result == "infra")
  @fs.write_file(root + "/blocked", b"not a directory")
  try write_reports(root + "/blocked/reports", [report]) catch {
    _ => ()
  } noraise {
    _ => fail("report write failure reported success")
  }
  try write_reports(root + "/empty", []) catch {
    _ => ()
  } noraise {
    _ => fail("empty required suite reported success")
  }
}

///|
async test "invalid case metadata fails before platform exclusion can hide it" {
  let root = @fs.tmpdir(prefix="mooncmd-platform-metadata-")
  defer @fs.rmdir(root, recursive=true)
  let fixture : Case = @json.from_json({
    "id": "platform-selection",
    "command": "true",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
  })
  for platforms in [[], ["linx"], ["linux", "linux"]] {
    let report = execute_contract(
      { ..fixture, host_platforms: Some(platforms), },
      root + "/missing-artifact",
      true,
      root + "/reports",
    )
    assert_eq(report.result, "infra")
    assert_eq(report.stage, "contract-validation")
    assert_false(report.semantic_pass())
  }
  let other = if host_platform() == "linux" { "windows" } else { "linux" }
  let excluded = { ..fixture, host_platforms: Some([other]), }
  let report = execute_contract(excluded, root, true, root + "/reports")
  assert_eq(report.result, "skip")
  let report = execute_contract(
    { ..excluded, expected_stderr_contains: Some(""), },
    root,
    true,
    root + "/reports",
  )
  assert_eq(report.result, "infra")
  assert_eq(report.stage, "contract-validation")
}
