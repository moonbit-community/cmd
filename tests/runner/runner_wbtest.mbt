///|
using @mv_scenarios {type OpenStdinObservation, open_stdin_observation_failures}

///|
test "byte differences identify offset and length" {
  assert_true(first_byte_difference(b"abc", b"axc").contains("at 1"))
  assert_true(first_byte_difference(b"abc", b"abcx").contains("length differs"))
}

///|
test "open stdin observations reject deadlines cleanup errors and missing exit" {
  let observed : OpenStdinObservation = {
    run: {
      output: { status: 1, stdout: b"", stderr: b"rejected\n", },
      timed_out: false,
      cleanup_error: None,
    },
    exited_before_stdin_close: true,
  }
  assert_eq(open_stdin_observation_failures(observed), [])
  assert_eq(
    open_stdin_observation_failures({
      ..observed,
      run: { ..observed.run, timed_out: true, },
    }),
    ["child exceeded the open-stdin deadline"],
  )
  assert_eq(
    open_stdin_observation_failures({
      ..observed,
      run: { ..observed.run, cleanup_error: Some("wait failed"), },
    }),
    ["child cleanup failed: wait failed"],
  )
  assert_eq(
    open_stdin_observation_failures({
      ..observed,
      exited_before_stdin_close: false,
    }),
    ["exit was not observed before closing stdin"],
  )
  assert_eq(
    open_stdin_observation_failures({
      run: {
        ..observed.run,
        timed_out: true,
        cleanup_error: Some("wait failed"),
      },
      exited_before_stdin_close: false,
    }).length(),
    3,
  )
}

///|
test "one scenario execution preserves its selectable ID and failure" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "shared",
    "command": "sh",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  let reports : Array[@testkit.CaseReport] = []
  let base = suite_report("scenario:shared", "wasm", 0L, ["observed failure"])
  append_scenario_reports(reports, fixture, base)
  assert_eq(reports.length(), 1)
  assert_eq(reports[0].id, "shared")
  assert_eq(reports[0].result, "fail")
  assert_eq(reports[0].detail, "observed failure")
}

///|
async test "scenario scheduler stays serial with eight requested jobs" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "serial",
    "command": "sh",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  let cases = Array::makei(8, index => { ..fixture, id: "serial-\{index}", })
  let reports : Array[@testkit.CaseReport] = []
  let active = Ref(0)
  let peak = Ref(0)
  let events : Array[String] = []
  run_scenario_batch(cases, reports, 8, fixture => {
    active.val += 1
    peak.val = Int32::max(peak.val, active.val)
    events.push("start:" + fixture.id)
    // Yield while the scenario owns shared state, so a parallel scheduler
    // would expose overlapping executions without timing assertions.
    @async.sleep(1)
    assert_eq(active.val, 1)
    events.push("finish:" + fixture.id)
    active.val -= 1
    suite_report("scenario:" + fixture.id, "wasm", @async.now(), [])
  })
  assert_eq(peak.val, 1)
  assert_eq(active.val, 0)
  assert_eq(reports.length(), 8)
  assert_eq(events.length(), 16)
  for index = 0; index < cases.length(); index = index + 1 {
    assert_eq(events[index * 2], "start:serial-\{index}")
    assert_eq(events[index * 2 + 1], "finish:serial-\{index}")
    assert_eq(reports[index].id, "serial-\{index}")
  }
}

///|
test "stream diagnostics select the commands actually executed by the cohort" {
  let cases = cohort_cases().filter(fixture => {
    fixture.comparison == Some("stress")
  })
  for command in ["seq", "wc"] {
    let selected = @testkit.select_cases(cases, [command], [])
    assert_eq(selected.map(fixture => fixture.id), ["stress-streams"])
  }
  assert_eq(cases[0].command, "seq")
  let environment = cohort_cases().filter(fixture => {
    fixture.id == "compat-environment"
  })
  assert_eq(@testkit.select_cases(environment, ["printenv"], []).length(), 1)
}

///|
async test "compatibility fixture cleanup errors propagate" {
  let root = @fs.tmpdir(prefix="mooncmd-cleanup-regression-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/file", b"not a directory")
  try cleanup_compat_fixture(root + "/file") catch {
    _ => ()
  } noraise {
    _ => fail("fixture cleanup failure was suppressed")
  }
}
