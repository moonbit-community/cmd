///|
fn real_test_contract(id : String, command : String) -> @testkit.Case raise {
  @json.from_json({
    "id": id,
    "command": command,
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "comparison": "contract",
  })
}

///|
fn real_test_local_result(fixture : @testkit.Case) -> Json {
  let report : @testkit.CaseReport = {
    id: fixture.id,
    command: fixture.command,
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: "macos",
    backend: "wasm",
    source_version: "independent local gate regression",
    duration_ms: 1L,
    observations: ["status", "stdout", "stderr"],
    missing_observations: [],
    evidence: None,
  }
  ToJson::to_json(report)
}

///|
test "local correctness joins exact identities and rejects duplicate substituted or missing passes" {
  let first = real_test_contract("local-first", "cat")
  let second = real_test_contract("local-second", "wc")
  let a = real_test_local_result(first)
  let b = real_test_local_result(second)
  let run : Json = { "failed": 0, "passed": 2, "skipped": 0 }
  assert_eq(real_local_result_errors([first, second], [a, b], run, "macos"), [])
  assert_true(
    real_local_result_errors([first, second], [a, a], run, "macos").any(error => {
      error.contains("missing or duplicate local identity")
    }),
  )
  let substituted = real_test_replace(b, "id", Json("unrequested-local-case"))
  assert_true(
    real_local_result_errors([first, second], [a, substituted], run, "macos").any(error => {
        error.contains("missing or duplicate local identity")
      },
    ),
  )
  assert_true(
    !real_local_result_errors(
      [first, second],
      [a],
      { "failed": 0, "passed": 1, "skipped": 0 },
      "macos",
    ).is_empty(),
  )
  assert_true(
    !real_local_result_errors(
      [],
      [],
      { "failed": 0, "passed": 0, "skipped": 0 },
      "macos",
    ).is_empty(),
  )
}

///|
test "local correctness rejects wrong ownership runtime verification incomplete stage and unobserved dimensions" {
  let fixture = real_test_contract("local-owner", "cat")
  let result = real_test_local_result(fixture)
  let run : Json = { "failed": 0, "passed": 1, "skipped": 0 }
  assert_eq(real_local_result_errors([fixture], [result], run, "macos"), [])
  for
    (key, value) in [
      ("command", Json("wc")),
      ("backend", Json("native")),
      ("platform", Json("linux")),
      ("verification", Json("differential")),
      ("missing_observations", Json(["stderr"])),
      ("missing_observations", Json::null()),
      ("stage", Json("candidate")),
      ("observations", Json::array([])),
      ("observations", Json(["status", "stdout"])),
      ("observations", Json::null()),
    ] {
    assert_true(
      !real_local_result_errors(
        [fixture],
        [real_test_replace(result, key, value)],
        run,
        "macos",
      ).is_empty(),
      msg=key,
    )
  }
  let expected : @testkit.ExpectedFile = @json.from_json({
    "path": "out",
    "content_text": "value",
  })
  let with_effect = { ..fixture, expected_files: Some([expected]), }
  assert_true(
    !real_local_result_errors([with_effect], [result], run, "macos").is_empty(),
  )
  let observed_effect = real_test_replace(
    result,
    "observations",
    Json(["status", "stdout", "stderr", "type", "content"]),
  )
  assert_eq(
    real_local_result_errors([with_effect], [observed_effect], run, "macos"),
    [],
  )
}

///|
test "local platform exclusions remain explicit and all-skip or illegal applicable skips cannot qualify" {
  let applicable = real_test_contract("local-posix", "cat")
  let excluded = {
    ..real_test_contract("local-windows", "wc"),
    host_platforms: Some(["windows"]),
  }
  let pass = real_test_local_result(applicable)
  let skip = real_test_replace(
    real_test_replace(
      real_test_replace(
        real_test_local_result(excluded),
        "result",
        Json("skip"),
      ),
      "stage",
      Json("platform"),
    ),
    "observations",
    Json::array([]),
  )
  assert_eq(
    real_local_result_errors(
      [applicable, excluded],
      [pass, skip],
      { "failed": 0, "passed": 1, "skipped": 1 },
      "macos",
    ),
    [],
  )
  assert_true(
    real_local_result_errors(
      [excluded],
      [skip],
      { "failed": 0, "passed": 0, "skipped": 1 },
      "macos",
    ).any(error => error.contains("all-skip")),
  )
  let unauthorized = { ..excluded, host_platforms: None, }
  assert_true(
    real_local_result_errors(
      [unauthorized],
      [skip],
      { "failed": 0, "passed": 0, "skipped": 1 },
      "macos",
    ).any(error => error.contains("applicable local witness did not complete")),
  )
  assert_true(
    real_local_result_errors(
      [applicable, excluded],
      [pass, real_test_replace(skip, "stage", Json("complete"))],
      { "failed": 0, "passed": 1, "skipped": 1 },
      "macos",
    ).any(error => error.contains("illegal platform skip")),
  )
  let posix = { ..applicable, host_platforms: Some(["posix"]), }
  assert_eq(
    real_local_result_errors(
      [posix],
      [pass],
      { "failed": 0, "passed": 1, "skipped": 0 },
      "macos",
    ),
    [],
  )
}

///|
test "local correctness counters and failed or infrastructure results cannot be erased by aggregate metadata" {
  let fixture = real_test_contract("local-counter", "cat")
  let result = real_test_local_result(fixture)
  let invalid_summaries : Array[Json] = [
    { "failed": 1, "passed": 1, "skipped": 0 },
    { "failed": 0, "passed": 0, "skipped": 0 },
    { "failed": 0, "passed": 1, "skipped": 1 },
    { "failed": 0, "passed": 1 },
  ]
  for run in invalid_summaries {
    assert_true(
      !real_local_result_errors([fixture], [result], run, "macos").is_empty(),
    )
  }
  for failure in ["fail", "infra", "skip"] {
    assert_true(
      !real_local_result_errors(
        [fixture],
        [real_test_replace(result, "result", Json(failure))],
        { "failed": 0, "passed": 1, "skipped": 0 },
        "macos",
      ).is_empty(),
    )
  }
}
