///|
async test "published mktemp scenario uses the selected coordinate and rejects bad effects" {
  let manifest = {
    ..network_manifest_for_test(),
    release_scope: Some(["mktemp"]),
    commands: [
      {
        ..network_manifest_for_test().commands[0],
        name: "mktemp",
        package_name: "cli/mktemp",
        version: "0.1.3",
      },
    ],
  }
  let windows = @platform.is_windows()
  let fixture = {
    ..release_case_for_test(
      if windows {
        "mktemp-option-effects-windows"
      } else {
        "mktemp-option-effects"
      },
      "mktemp",
    ),
    comparison: Some("scenario"),
    host_platforms: Some(if windows { ["windows"] } else { ["linux", "macos"] }),
  }
  assert_true(release_mktemp_scenario(fixture))
  let reports : Array[CaseReport] = []
  let evidence = @fs.tmpdir(prefix="release-mktemp-test-")
  defer @fs.rmdir(evidence, recursive=true)
  let called = Ref(false)
  run_mktemp_release_scenario(
    manifest,
    fixture,
    "chosen-moonx",
    15000,
    None,
    reports,
    Some(evidence),
    candidate_executor=launch => {
      called.val = true
      assert_eq(launch.program, "chosen-moonx")
      assert_eq(launch.args, ["cli/mktemp@0.1.3", "--"])
      assert_eq(launch.stdin, b"")
      assert_eq(launch.environment.get("TMPDIR"), Some(launch.cwd + "/tmp"))
      {
        output: { status: 7, stdout: b"invalid\n", stderr: b"", },
        timed_out: false,
        cleanup_error: None,
      }
    },
  )
  assert_true(called.val)
  guard reports is [report] else { fail("one report required") }
  assert_eq(report.category, "candidate_failure")
  assert_true(
    shared_report(report, [fixture], false, Map([])).observations.is_empty(),
  )
  let passed = shared_report(
    { ..report, category: "passed", },
    [fixture],
    false,
    Map([]),
  )
  assert_eq(passed.verification, "contract")
  for dimension in ["status", "stdout", "stderr", "file-content", "file-type"] {
    assert_true(passed.observations.contains(dimension))
  }
  assert_eq(passed.observations.contains("file-mode"), !windows)
}
