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
test "backend pair normalizes only declared workspace output placeholders" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "path",
    "command": "which",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "expected_stdout_text": "${WORK}/bin\\tool\n",
  })
  assert_eq(
    pair_stream(fixture, b"/native/bin\\tool\n", "stdout", "/native"),
    pair_stream(fixture, b"/wasm/bin\\tool\n", "stdout", "/wasm"),
  )
  assert_eq(
    pair_stream(fixture, b"/native/error", "stderr", "/native"),
    b"/native/error",
  )
  let literal = { ..fixture, expected_stdout_text: Some("/native/bin/tool\n"), }
  assert_eq(
    pair_stream(literal, b"/native/bin/tool\n", "stdout", "/native"),
    b"/native/bin/tool\n",
  )
  assert_true(
    pair_stream(fixture, b"/native/bin/wrong\n", "stdout", "/native") !=
    pair_stream(fixture, b"/wasm/bin/tool\n", "stdout", "/wasm"),
  )
}

///|
test "scenario reports preserve legacy and typed evidence identities" {
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
  let base = suite_report("scenario:shared", "native", 0L, ["observed failure"])
  append_scenario_reports(reports, fixture, base)
  assert_eq(reports.length(), 2)
  assert_eq(reports[0].id, "shared")
  assert_eq(reports[1].id, "scenario:shared")
  assert_eq(reports[0].result, "fail")
  assert_eq(reports[1].detail, reports[0].detail)
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
    suite_report("scenario:" + fixture.id, "native", @async.now(), [])
  })
  assert_eq(peak.val, 1)
  assert_eq(active.val, 0)
  assert_eq(reports.length(), 16)
  assert_eq(events.length(), 16)
  for index = 0; index < cases.length(); index = index + 1 {
    assert_eq(events[index * 2], "start:serial-\{index}")
    assert_eq(events[index * 2 + 1], "finish:serial-\{index}")
    assert_eq(reports[index * 2].id, "serial-\{index}")
    assert_eq(reports[index * 2 + 1].id, "scenario:serial-\{index}")
  }
}

///|
test "suite filtering respects case kind before fixtures or artifacts" {
  let cohorts = cohort_cases()
  let selected = @testkit.select_cases(cohorts, ["tail"], ["compat-tail-follow"])
  assert_eq(selected.length(), 1)
  assert_true(case_in_suites(selected[0], ["compat"]))
  assert_false(case_in_suites(selected[0], ["oracle", "contract", "scenarios"]))
  assert_true(
    cohorts
    .filter(item => case_in_suites(item, ["gnu"]))
    .all(item => item.id == "gnu-host"),
  )
  let boundary : @testkit.Case = @json.from_json({
    "id": "candidate-boundary",
    "command": "cp",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 1,
    "normalizations": [],
    "comparison": "contract",
    "expected_rejection": "metadata unavailable",
  })
  assert_true(case_in_suites(boundary, ["contract"]))
  assert_false(case_in_suites(boundary, ["oracle"]))
  assert_true(
    case_in_suites({ ..boundary, comparison: None, expected_status: 0, }, [
      "oracle",
    ]),
  )
}

///|
test "Windows mv scenarios select their actual backend and never claim a pair" {
  for id in ["mv-windows-native-links", "mv-windows-wasm-links-boundary"] {
    let fixture : @testkit.Case = @json.from_json({
      "id": id,
      "command": "mv",
      "args": [],
      "files": [],
      "environment": {},
      "expected_status": 0,
      "normalizations": [],
      "comparison": "scenario",
    })
    assert_true(case_in_suites(fixture, ["scenarios"]))
    assert_false(case_in_suites(fixture, ["backend-pair"]))
    assert_false(case_in_suites(fixture, ["contract", "oracle"]))
    assert_eq(
      windows_mv_scenario_backend(id, false),
      id == "mv-windows-native-links",
    )
    assert_eq(
      windows_mv_scenario_backend(id, true),
      id == "mv-windows-wasm-links-boundary",
    )
  }
}
