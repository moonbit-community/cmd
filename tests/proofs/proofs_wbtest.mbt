///|
fn proof_test_index() -> @registry.Registry raise {
  @json.from_json({
    "schema": 3,
    "release_commands": [],
    "entries": [
      {
        "behavior_id": "case:sample",
        "command": "cat",
        "status": "supported",
        "implementation": "json-case",
        "source": "unused",
        "case_id": "sample",
        "aliases": ["alias"],
        "platforms": [],
        "oracle_profile": "",
      },
    ],
  })
}

///|
fn proof_test_case() -> @testkit.Case raise {
  @json.from_json({
    "id": "sample",
    "command": "cat",
    "args": ["-n"],
    "stdin_text": "a\n",
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "expected_stdout_text": "     1\ta\n",
    "expected_stderr_text": "",
    "comparison": "contract",
  })
}

///|
fn proof_test_manifest() -> Json {
  {
    "schema": 1,
    "obligations": [
      {
        "claim_id": "cat:number",
        "command": "cat",
        "reviewed": true,
        "kind": "supported-option",
        "case_ids": ["sample"],
        "activation": "Nonempty input receives the exact asserted line number and tab",
        "scope": "one ordinary record and this selected formatting operation",
      },
    ],
  }
}

///|
test "proof definitions reject tags alone missing claims aliases and cross-command cases" {
  let index = proof_test_index()
  let fixture = proof_test_case()
  let contract : @contracts.CommandContract = {
    name: "cat",
    tier: Core,
    input: FileOrStdin,
    output: ByteStream,
    exit_codes: [0, 1],
    capabilities: [],
    options: ["number"],
  }
  let manifest = proof_test_manifest()
  assert_eq(proof_definitions_errors(manifest, index, [fixture], [contract]), [])
  assert_false(
    proof_definitions_errors(
      { "schema": 1, "obligations": [] },
      index,
      [fixture],
      [contract],
    ).is_empty(),
  )
  let rows = proof_array(proof_field(manifest, "obligations"))
  assert_false(
    proof_definitions_errors(
      { "schema": 1, "obligations": [rows[0], rows[0]] },
      index,
      [fixture],
      [contract],
    ).is_empty(),
  )
  assert_false(
    proof_definitions_errors(manifest, index, [{ ..fixture, command: "wc", }], [
      contract,
    ]).is_empty(),
  )
  assert_false(
    proof_definitions_errors(
      manifest,
      index,
      [{ ..fixture, comparison: None, }],
      [contract],
    ).is_empty(),
  )
  assert_false(
    proof_definitions_errors(
      manifest,
      index,
      [{ ..fixture, expected_stdout_text: None, }],
      [contract],
    ).is_empty(),
  )
  assert_false(
    proof_definitions_errors(
      manifest,
      index,
      [
        {
          ..fixture,
          expected_stderr_text: None,
          expected_stderr_contains: Some("error"),
        },
      ],
      [contract],
    ).is_empty(),
  )
  let metadata_catalog = { ..contract, options: ["help"], }
  let metadata : Json = {
    "schema": 1,
    "obligations": [
      {
        "claim_id": "cat:help",
        "command": "cat",
        "reviewed": true,
        "kind": "metadata",
        "case_ids": ["sample"],
        "activation": "This ordinary JSON case must not replace the typed metadata observer",
        "scope": "stdin unread and exact package version are required",
      },
    ],
  }
  assert_false(
    proof_definitions_errors(metadata, index, [fixture], [metadata_catalog]).is_empty(),
  )
}

///|
test "proof joins actual producer reports and rejects missing skipped duplicated or changed definitions" {
  let fixture = proof_test_case()
  let report : @testkit.CaseReport = {
    id: "sample",
    command: "cat",
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: "macos",
    backend: "wasm",
    source_version: "independent contract",
    duration_ms: 1L,
    observations: ["status", "stdout", "stderr"],
    missing_observations: [],
    evidence: None,
  }
  let observed = ToJson::to_json(report)
  let manifest = proof_test_manifest()
  let index = proof_test_index()
  assert_true(
    join_proof_results(
      manifest,
      index,
      [fixture],
      [fixture],
      [observed],
      "macos",
    )
    is { "reviewed_profile_passed": True, .. },
  )
  for
    results in [
      [],
      [observed, observed],
      [ToJson::to_json({ ..report, result: "skip", })],
      [ToJson::to_json({ ..report, result: "infra", })],
      [ToJson::to_json({ ..report, missing_observations: ["stderr"], })],
    ] {
    assert_true(
      join_proof_results(
        manifest,
        index,
        [fixture],
        [fixture],
        results,
        "macos",
      )
      is { "reviewed_profile_passed": False, .. },
    )
  }
  assert_true(
    join_proof_results(manifest, index, [fixture], [], [observed], "macos")
    is { "reviewed_profile_passed": False, .. },
  )
  assert_true(
    join_proof_results(
      manifest,
      index,
      [fixture],
      [{ ..fixture, expected_stdout_text: Some("wrong"), }],
      [observed],
      "macos",
    )
    is { "reviewed_profile_passed": False, .. },
  )
  for
    invalid in [
      { ..report, platform: "linux", },
      { ..report, backend: "native", },
      { ..report, observations: ["status", "stdout"], },
    ] {
    assert_true(
      join_proof_results(
        manifest,
        index,
        [fixture],
        [fixture],
        [ToJson::to_json(invalid)],
        "macos",
      )
      is { "reviewed_profile_passed": False, .. },
    )
  }
  let posix = { ..fixture, host_platforms: Some(["posix"]), }
  let excluded = join_proof_results(
    manifest,
    index,
    [posix],
    [posix],
    [],
    "windows",
  )
  assert_true(
    excluded
    is { "reviewed_profile_passed": False, "full_catalog_qualified": False, .. },
  )
}

///|
test "file-effect obligations require actual observation dimensions" {
  let fixture = proof_test_case()
  guard ToJson::to_json(fixture) is Object(fields) else {
    fail("invalid case encoding")
  }
  fields["expected_files"] = [{ "path": "out", "content_text": "value" }]
  let with_effects : @testkit.Case = @json.from_json(Json(fields))
  let report : @testkit.CaseReport = {
    id: "sample",
    command: "cat",
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: "macos",
    backend: "wasm",
    source_version: "independent contract",
    duration_ms: 1L,
    observations: ["status", "stdout", "stderr"],
    missing_observations: [],
    evidence: None,
  }
  assert_true(
    join_proof_results(
      proof_test_manifest(),
      proof_test_index(),
      [with_effects],
      [with_effects],
      [ToJson::to_json(report)],
      "macos",
    )
    is { "reviewed_profile_passed": False, .. },
  )
  assert_true(
    join_proof_results(
      proof_test_manifest(),
      proof_test_index(),
      [with_effects],
      [with_effects],
      [
        ToJson::to_json({
          ..report,
          observations: ["status", "stdout", "stderr", "type", "content"],
        }),
      ],
      "macos",
    )
    is { "reviewed_profile_passed": True, .. },
  )
}
