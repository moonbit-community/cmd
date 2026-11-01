///|
fn scenario_test_fixture() -> @testkit.Case raise {
  @json.from_json({
    "id": "shared",
    "command": "curl",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "comparison": "scenario",
  })
}

///|
test "whole-run result integrity rejects hidden failures and unknown statuses" {
  let good : Json = {
    "passed": 1,
    "failed": 0,
    "skipped": 0,
    "results_sha256": "digest",
  }
  assert_eq(proof_result_errors(good, [{ "result": "pass" }], "digest"), [])
  assert_false(
    proof_result_errors(
      good,
      [{ "result": "pass" }, { "result": "fail" }],
      "digest",
    ).is_empty(),
  )
  assert_false(
    proof_result_errors(good, [{ "result": "pass" }], "changed").is_empty(),
  )
  assert_false(
    proof_result_errors(good, [{ "result": "unknown" }], "digest").is_empty(),
  )
}

///|
fn scenario_test_registry() -> @registry.Registry raise {
  @json.from_json({
    "schema": 3,
    "release_commands": [],
    "entries": [
      {
        "behavior_id": "scenario:shared",
        "command": "curl",
        "status": "supported",
        "implementation": "stateful-scenario",
        "source": "shared",
        "case_id": "",
        "aliases": [],
        "platforms": [],
        "oracle_profile": "",
      },
    ],
  })
}

///|
test "multi-command scene binding requires its own complete actual assertions" {
  let fixture = scenario_test_fixture()
  let registry = scenario_test_registry()
  let catalog : Json = {
    "schema": 1,
    "scenarios": [
      {
        "case_id": "shared",
        "assertions": [
          {
            "id": "wget/request",
            "command": "wget",
            "relation": "equal",
            "expected": { "count": 2 },
            "observations": ["request-count"],
          },
          {
            "id": "curl/request",
            "command": "curl",
            "relation": "equal",
            "expected": 1,
            "observations": ["request-count"],
          },
        ],
      },
    ],
  }
  let binding : Json = { "case_id": "shared", "assertions": ["wget/request"] }
  let report : @testkit.CaseReport = {
    id: "shared",
    command: "curl",
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: "macos",
    backend: "wasm",
    source_version: "test",
    duration_ms: 1L,
    observations: ["status", "stdout", "stderr"],
    missing_observations: [],
    local_contract: None,
    evidence: None,
  }
  let receipts : Json = {
    "schema": 1,
    "scenarios": [
      {
        "schema": 1,
        "case_id": "shared",
        "assertions": [
          {
            "id": "wget/request",
            "command": "wget",
            "relation": "equal",
            "actual": { "count": 2 },
            "expected": { "count": 2 },
          },
          {
            "id": "curl/request",
            "command": "curl",
            "relation": "equal",
            "actual": 1,
            "expected": 1,
          },
        ],
      },
    ],
  }
  assert_true(
    proof_scenario_result(
      binding,
      "wget",
      registry,
      [fixture],
      [fixture],
      [ToJson::to_json(report)],
      catalog,
      receipts,
      "macos",
    )
    is { "passed": True, .. },
  )
  assert_true(
    proof_scenario_result(
      binding,
      "curl",
      registry,
      [fixture],
      [fixture],
      [ToJson::to_json(report)],
      catalog,
      receipts,
      "macos",
    )
    is { "passed": False, .. },
  )
  for
    invalid in [
      Json::null(),
      (
        {
          "schema": 1,
          "scenarios": [{ "schema": 1, "case_id": "shared", "assertions": [] }],
        } : Json),
    ] {
    assert_true(
      proof_scenario_result(
        binding,
        "wget",
        registry,
        [fixture],
        [fixture],
        [ToJson::to_json(report)],
        catalog,
        invalid,
        "macos",
      )
      is { "passed": False, .. },
    )
  }
  for
    bad in [
      { ..report, result: "skip", },
      { ..report, result: "infra", },
      { ..report, stage: "timeout", },
      { ..report, backend: "native", },
      { ..report, platform: "linux", },
    ] {
    assert_true(
      proof_scenario_result(
        binding,
        "wget",
        registry,
        [fixture],
        [fixture],
        [ToJson::to_json(bad)],
        catalog,
        receipts,
        "macos",
      )
      is { "passed": False, .. },
    )
  }
  assert_true(
    proof_scenario_result(
      binding,
      "wget",
      registry,
      [fixture],
      [fixture],
      [ToJson::to_json(report), ToJson::to_json(report)],
      catalog,
      receipts,
      "macos",
    )
    is { "passed": False, .. },
  )
}

///|
test "driver build receipt requires exact source and binary identities before execution" {
  let sources : Json = [{ "path": "assertion.mbt", "sha256": "source" }]
  let snapshot : Json = {
    "scenario_contracts": { "assertion_sources": sources },
    "driver_sha256": "a".repeat(64),
    "prepared_at_ms": Json(30L),
  }
  let build : Json = {
    "schema": 1,
    "status": 0,
    "program": "moon",
    "arguments": [
      "build", "--target", "native", "--deny-warn", "tests/runner", "tests/proofs",
    ],
    "assertion_sources": sources,
    "driver_sha256": "a".repeat(64),
    "started_at_ms": Json(10L),
    "completed_at_ms": Json(20L),
  }
  assert_eq(proof_build_errors(build, snapshot, 40L, 5L), [])
  assert_false(proof_build_errors(build, snapshot, 40L, 15L).is_empty())
  assert_false(proof_build_errors(build, snapshot, 25L, 5L).is_empty())
  assert_false(proof_build_errors(Json::null(), snapshot, 40L, 5L).is_empty())
}
