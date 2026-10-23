///|
fn ci_test_frozen() -> CiFrozenBinding {
  {
    manifest_hash: @testkit.sha256_text("published-manifest"),
    corpus_hash: @testkit.sha256_text("published-corpus"),
    registry_hash: @testkit.sha256_text("frozen-registry"),
    corpus_path: "unused",
    coordinates: ["cli/echo@0.2.1"],
  }
}

///|
async test "CI published requirements come from reviewed intent and registry obligations" {
  let entry = audit_entry()
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let impact = ci_test_impact(entry.behavior_id)
  let context = ci_test_context()
  let intent = ci_scope_test_intent([ci_scope_test_requirement(entry)], [])
  assert_true(
    ci_published_enabled({ ..context, event: "schedule", base: "", }, None),
  )
  assert_true(
    ci_published_enabled(
      { ..context, event: "workflow_dispatch", },
      Some(intent),
    ),
  )
  assert_true(
    ci_published_enabled(
      context,
      Some({ ..intent, selection: { ..intent.selection, mode: "full", }, }),
    ),
  )
  try ci_published_enabled(context, None) catch {
    error => assert_true(error.to_string().contains("fresh actual-range scope"))
  } noraise {
    _ => fail("published requirements accepted a missing range scope")
  }
  assert_false(ci_impact_needs_published(impact, registry))
  assert_true(
    ci_impact_needs_published(
      { ..impact, required_evidence: ["published-differential"], },
      registry,
    ),
  )
  assert_true(
    ci_impact_needs_published(impact, {
      ..registry,
      entries: [{ ..entry, required_evidence: ["published-differential"], }],
    }),
  )
  assert_false(ci_report_roles("linux").contains("published-differential"))
  assert_true(
    ci_report_roles("linux", published=true).contains("published-differential"),
  )
  assert_false(
    ci_report_roles("windows", published=true).contains(
      "published-differential",
    ),
  )
}

///|
test "CI frozen registry exception requires the exact manifest corpus platform and coordinates" {
  let binding = ci_test_frozen()
  let metadata = {
    ..audit_metadata("published"),
    platform: "linux",
    manifest_hash: binding.manifest_hash,
    case_corpus_hash: binding.corpus_hash,
    registry_hash: binding.registry_hash,
    moonx_coordinates: binding.coordinates,
  }
  assert_true(ci_frozen_metadata_matches(metadata, binding))
  for
    changed in [
      { ..metadata, registry_hash: @testkit.sha256_text("other"), },
      { ..metadata, manifest_hash: @testkit.sha256_text("other"), },
      { ..metadata, case_corpus_hash: @testkit.sha256_text("other"), },
      { ..metadata, platform: "macos", },
      { ..metadata, moonx_coordinates: ["cli/echo@9.9.9"], },
      { ..metadata, moonx_coordinates: [], },
    ] {
    assert_false(ci_frozen_metadata_matches(changed, binding))
  }
  let failures = validate_metadata(
    metadata,
    @testkit.sha256_text("current-registry"),
    [binding.corpus_hash],
    [binding.manifest_hash],
    metadata.git_revision,
  )
  assert_true(
    failures.any(message => message.contains("registry_hash does not match")),
  )
}

///|
async test "CI frozen cases cannot prove current behavior after canonical expectations change" {
  let root = @fs.tmpdir(prefix="mooncmd-ci-frozen-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture : @testkit.Case = @json.from_json({
    "id": "echo",
    "command": "echo",
    "args": ["current"],
    "files": [],
    "environment": {},
    "normalizations": [],
    "comparison": "contract",
    "expected_status": 0,
    "expected_stdout_text": "current\n",
    "expected_stderr_text": "",
  })
  let current : Json = { "schema": 1, "cases": [ToJson::to_json(fixture)] }
  @fs.write_file(root + "/current.json", current.stringify())
  @fs.write_file(root + "/frozen.json", current.stringify())
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [{ ..audit_entry(), source: "current.json", }],
  }
  let binding = { ..ci_test_frozen(), corpus_path: root + "/frozen.json", }
  assert_eq(ci_frozen_selected_ids(binding, registry, root), ["echo"])
  let older = { ..fixture, expected_stdout_text: Some("older\n"), }
  let frozen : Json = { "schema": 1, "cases": [ToJson::to_json(older)] }
  @fs.write_file(root + "/frozen.json", frozen.stringify())
  assert_eq(ci_frozen_selected_ids(binding, registry, root), [])
}

///|
test "CI published differential requires actual rows exact coordinates and sealed oracle evidence" {
  let entry = {
    ..audit_entry(),
    required_backends: ["wasm"],
    required_evidence: ["published-differential"],
    oracle_profile: "pinned-oracle-v1",
  }
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry],
  }
  let declaration = {
    ..declaration_for_test(entry.behavior_id, "pass"),
    required_backends: [],
    required_evidence: [],
    coverage: [
      {
        ..declaration_for_test(entry.behavior_id, "pass").coverage[0],
        backends: ["wasm"],
        evidence: ["published-differential"],
        report: Some("published/./summary.jsonl"),
      },
    ],
  }
  let binding = ci_test_frozen()
  let metadata = {
    ..audit_metadata("published"),
    platform: "linux",
    registry_hash: binding.registry_hash,
    oracle_profile_id: entry.oracle_profile,
    oracle_image_digest: "sha256:" + "c".repeat(64),
    oracle_versions_hash: "d".repeat(64),
    docker_version: "docker-test",
    moonx_coordinates: binding.coordinates,
  }
  let row = {
    ..audit_row("published", "published-wasm", "differential"),
    platform: "linux",
    source_version: "cli/echo@0.2.1",
    registry_revision: binding.registry_hash,
    oracle_profile_id: entry.oracle_profile,
  }
  let bundle : EvidenceBundle = {
    report_path: @path.Path("published/summary.jsonl").normalize().to_string(),
    metadata,
    rows: [row],
    selected_ids: ["echo"],
    oracle_verified: true,
    published_coordinates: binding.coordinates,
  }
  assert_true(
    validate_report_evidence(declaration, registry, [bundle], platforms=[
      "linux", "macos", "windows",
    ]).is_empty(),
  )
  for
    changed in [
      { ..bundle, rows: [], },
      { ..bundle, published_coordinates: ["cli/echo@9.9.9"], },
      { ..bundle, oracle_verified: false, },
      { ..bundle, selected_ids: [], },
      {
        ..bundle,
        report_path: @path.Path("published/another-summary.jsonl")
        .normalize()
        .to_string(),
      },
    ] {
    assert_false(
      validate_report_evidence(declaration, registry, [changed], platforms=[
        "linux", "macos", "windows",
      ]).is_empty(),
    )
  }
}
