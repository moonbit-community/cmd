///|
async test "direct child cleanup errors retain evidence without semantic promotion" {
  let workspace = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-child-cleanup-")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let row = lifecycle_release_command()
  let reports : Array[CaseReport] = []
  let fixtures : Array[ReleaseCase] = []
  let started = @async.now()
  for timed_out in [false, true] {
    let fixture = {
      ..release_case_for_test(
        if timed_out {
          "cleanup-after-timeout"
        } else {
          "cleanup-after-exit"
        },
        "echo",
      ),
      coverage: Some(["literal-operand"]),
      files: [
        {
          path: "retained.bin",
          content_hex: Some("00ff80"),
          content_text: None,
          kind: None,
          target: None,
          mode: None,
          atime: None,
          mtime: None,
        },
      ],
    }
    fixtures.push(fixture)
    let calls = Ref(0)
    run_case(
      "injected-moonx",
      directory + "/must-not-run-docker",
      "must-not-run-oracle",
      row,
      fixture,
      true,
      900,
      None,
      None,
      None,
      reports,
      Some(directory),
      candidate_executor=invocation => {
        calls.val += 1
        assert_eq(
          @fs.read_file(invocation.cwd + "/retained.bin").binary(),
          b"\x00\xff\x80",
        )
        {
          output: {
            status: 0,
            stdout: b"completed candidate\x00",
            stderr: b"diagnostic\xff",
          },
          timed_out,
          cleanup_error: Some("direct child wait failed"),
        }
      },
    )
    assert_eq(calls.val, 1)
    let saved = reports[reports.length() - 1]
    assert_eq(saved.category, "cleanup_failure")
    assert_true(saved.detail.contains("direct child wait failed"))
    let report = shared_report(saved, [fixture], true, Map([]))
    assert_eq(report.result, "infra")
    assert_false(report.semantic_pass())
    assert_true(report.observations.is_empty())
    guard report.evidence is Some(evidence) else {
      fail("uncertain child cleanup must retain execution evidence")
    }
    assert_eq(
      @fs.read_file(evidence + "/candidate.stdout").binary(),
      b"completed candidate\x00",
    )
    assert_eq(
      @fs.read_file(evidence + "/candidate.stderr").binary(),
      b"diagnostic\xff",
    )
    assert_eq(
      @fs.read_file(evidence + "/candidate/retained.bin").binary(),
      b"\x00\xff\x80",
    )
    assert_eq(@fs.exists(evidence + "/candidate.capture-incomplete"), timed_out)
    assert_false(@fs.exists(evidence + "/oracle.stdout"))
    assert_false(@fs.exists(evidence + "/oracle.stderr"))
  }
  assert_eq(reports.length(), 2)
  write_report(
    directory,
    reports,
    fixtures,
    true,
    Map([]),
    workspace + "/tests/release_runner/current/candidate.json",
    workspace + "/tests/release_runner/current/active-cases.json",
    started,
    "",
    "",
  )
  let rows = @fs.read_file(directory + "/summary.jsonl")
    .text()
    .split("\n")
    .filter(line => line != "")
    .collect()
  assert_eq(rows.length(), 2)
  for line in rows {
    match @json.parse(line.to_owned()) {
      {
        "result": String(result),
        "stage": String(stage),
        "observations": Array(observations),
        ..
      } => {
        assert_eq(result, "infra")
        assert_eq(stage, "cleanup_failure")
        assert_true(observations.is_empty())
      }
      _ => fail("saved summary lost child cleanup uncertainty")
    }
  }
  let coverage_rows = @fs.read_file(directory + "/coverage.jsonl")
    .text()
    .split("\n")
    .filter(line => line != "")
    .collect()
  assert_eq(coverage_rows.length(), 2)
  for line in coverage_rows {
    match @json.parse(line.to_owned()) {
      { "options_verified": Array(verified), .. } =>
        assert_true(verified.is_empty())
      _ => fail("saved coverage lost the cleanup failure")
    }
  }
}
