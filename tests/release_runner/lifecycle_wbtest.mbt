///|
fn lifecycle_release_command() -> ReleaseCommand {
  {
    name: "echo",
    package_name: "cli/echo",
    version: "0.1.5",
    published: true,
    compare_profile: "gnu",
    supported_options: [],
    policy_sensitive: false,
  }
}

///|
async fn check_candidate_boundary_failure(
  id : String,
  output : @testkit.RunResult,
  category : String,
) -> Unit {
  let root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-release-boundary-")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let fixture = {
    ..release_case_for_test(id, "echo"),
    args: ["--", "sentinel"],
    stdin_hex: Some("00ff"),
    environment: { "LIFECYCLE_MARKER": "candidate-boundary" },
    timeout_ms: Some(731),
    coverage: Some(["literal-operand"]),
    files: [
      {
        path: "preserved.bin",
        content_hex: Some("0080ff"),
        content_text: None,
        kind: None,
        target: None,
        mode: None,
        atime: None,
        mtime: None,
      },
    ],
  }
  let row = lifecycle_release_command()
  let reports : Array[CaseReport] = []
  let calls : Array[CandidateInvocation] = []
  let started = @async.now()
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
      calls.push(invocation)
      { output, timed_out: false, cleanup_error: None, }
    },
  )
  assert_eq(calls.length(), 1)
  let invocation = calls[0]
  assert_eq(invocation.program, "injected-moonx")
  assert_eq(invocation.args, ["cli/echo@0.1.5", "--", "--", "sentinel"])
  assert_eq(invocation.timeout_ms, 731)
  assert_eq(invocation.stdin, b"\x00\xff")
  assert_eq(
    invocation.environment.get("LIFECYCLE_MARKER"),
    Some("candidate-boundary"),
  )
  assert_eq(invocation.environment.get("LC_ALL"), Some("C"))
  assert_eq(invocation.environment.get("TZ"), Some("UTC"))
  assert_eq(reports.length(), 1)
  assert_eq(reports[0].category, category)
  let report = shared_report(reports[0], [fixture], true, Map([]))
  assert_eq(report.result, "infra")
  assert_eq(report.verification, "differential")
  assert_false(report.semantic_pass())
  assert_true(report.observations.is_empty())
  guard report.evidence is Some(evidence) else {
    fail("candidate infrastructure failure must retain its case directory")
  }
  assert_eq(
    invocation.cwd,
    @path.Path(evidence).join(Path("candidate")).to_string(),
  )
  assert_eq(
    @fs.read_file(evidence + "/candidate.stdout").binary(),
    output.stdout,
  )
  assert_eq(
    @fs.read_file(evidence + "/candidate.stderr").binary(),
    output.stderr,
  )
  assert_eq(
    @fs.read_file(evidence + "/candidate/preserved.bin").binary(),
    b"\x00\x80\xff",
  )
  assert_false(@fs.exists(evidence + "/oracle.stdout"))
  assert_false(@fs.exists(evidence + "/oracle.stderr"))
  write_report(
    directory,
    reports,
    [fixture],
    true,
    Map([]),
    root + "/tests/release_runner/current/candidate.json",
    root + "/tests/release_runner/current/active-cases.json",
    started,
    "",
    "",
  )
  match @json.parse(@fs.read_file(directory + "/summary.jsonl").text()) {
    {
      "id": String(saved_id),
      "result": String(result),
      "stage": String(stage),
      "source_version": String(coordinate),
      "evidence": String(saved_evidence),
      "observations": Array(observations),
      ..
    } => {
      assert_eq(saved_id, fixture.id)
      assert_eq(result, "infra")
      assert_eq(stage, category)
      assert_eq(coordinate, "cli/echo@0.1.5")
      assert_eq(saved_evidence, evidence)
      assert_true(observations.is_empty())
    }
    _ => fail("release summary lost candidate infrastructure evidence")
  }
  match @json.parse(@fs.read_file(directory + "/coverage.jsonl").text()) {
    { "options_verified": Array(verified), .. } =>
      assert_true(verified.is_empty())
    _ => fail("release coverage lost the failed case")
  }
}

///|
async test "MoonX asset absence retains execution evidence without semantic promotion" {
  check_candidate_boundary_failure(
    "missing-published-asset",
    {
      status: 255,
      stdout: b"partial launcher output\x00",
      stderr: b"Prebuilt wasm asset does not exist\n",
    },
    "asset_unavailable",
  )
}

///|
async test "registry transport failure retains execution evidence without semantic promotion" {
  check_candidate_boundary_failure(
    "registry-transport-failure",
    {
      status: 1,
      stdout: b"partial registry output\xff",
      stderr: b"failed to read registry asset response: connection reset\n",
    },
    "registry_transport",
  )
}

///|
async test "published smoke execution never overlaps candidates when jobs exceed one" {
  let root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-release-concurrency-")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let fixtures = ["first", "second", "third"].map(id => {
    ..release_case_for_test(id, "echo"),
    args: [id],
    comparison: Some("contract"),
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
  })
  let manifest : ReleaseManifest = {
    schema: 2,
    candidate: Some(false),
    release_scope: None,
    core_version: Some("0.5.0"),
    base_manifest: "cases.json",
    commands: [lifecycle_release_command()],
    case_ids: [],
    extra_cases: fixtures,
  }
  // The differential contract-only control proves that the injected boundary
  // can overlap. Smoke must serialize the same async case execution even with
  // the same requested jobs and fixtures that carry no timestamp restriction.
  for suite in ["smoke", "differential"] {
    let report_root = directory + "/" + suite
    @fs.mkdir(report_root)
    let active = Ref(0)
    let peak = Ref(0)
    let calls : Array[String] = []
    let events : Array[String] = []
    let reports : Array[CaseReport] = []
    let timings : Map[String, Int64] = Map([])
    let started = @async.now()
    run_selected_cases(
      manifest,
      fixtures,
      "injected-moonx",
      directory + "/must-not-run-docker",
      "must-not-run-oracle",
      suite,
      5000,
      None,
      None,
      None,
      reports,
      timings,
      4,
      Some(report_root),
      candidate_executor=invocation => {
        assert_eq(invocation.args.length(), 3)
        assert_eq(invocation.args[0], "cli/echo@0.1.5")
        assert_eq(invocation.args[1], "--")
        let id = invocation.args[2]
        active.val += 1
        peak.val = peak.val.max(active.val)
        calls.push(id)
        events.push("start:" + id)
        defer {
          events.push("finish:" + id)
          active.val -= 1
        }
        if suite == "smoke" {
          @async.sleep(5)
        } else {
          let all_started = @async.with_timeout_opt(2000, () => {
            while calls.length() < fixtures.length() {
              @async.sleep(1)
            }
          })
          assert_true(
            all_started is Some(_),
            msg="parallel control failed to start all cases",
          )
        }
        {
          output: { status: 0, stdout: b"", stderr: b"", },
          timed_out: false,
          cleanup_error: None,
        }
      },
    )
    assert_eq(active.val, 0)
    assert_eq(calls.length(), fixtures.length())
    assert_eq(reports.length(), fixtures.length())
    assert_true(reports.all(report => report.category == "passed"))
    if suite == "smoke" {
      assert_eq(peak.val, 1)
      for index = 0; index < calls.length(); index = index + 1 {
        assert_eq(events[index * 2], "start:" + calls[index])
        assert_eq(events[index * 2 + 1], "finish:" + calls[index])
      }
    } else {
      assert_eq(peak.val, fixtures.length())
    }
    for fixture in fixtures {
      assert_false(
        @fs.exists(report_root + "/" + report_directory_name(fixture.id)),
      )
      assert_true(timings.contains(fixture.id))
    }
    write_report(
      report_root,
      reports,
      fixtures,
      suite == "differential",
      timings,
      root + "/tests/release_runner/current/candidate.json",
      root + "/tests/release_runner/current/active-cases.json",
      started,
      "",
      "",
    )
    let rows = @fs.read_file(report_root + "/summary.jsonl")
      .text()
      .split("\n")
      .filter(line => !line.trim().is_empty())
      .collect()
    assert_eq(rows.length(), fixtures.length())
    for row in rows {
      match @json.parse(row.to_owned()) {
        {
          "result": String(result),
          "verification": String(verification),
          "source_version": String(coordinate),
          "observations": Array(observations),
          ..
        } => {
          assert_eq(result, "pass")
          assert_eq(verification, "contract")
          assert_eq(coordinate, "cli/echo@0.1.5")
          assert_true(observations.contains(Json("stdout")))
          assert_true(observations.contains(Json("stderr")))
        }
        _ => fail("serialized execution lost its passing contract evidence")
      }
    }
  }
}
