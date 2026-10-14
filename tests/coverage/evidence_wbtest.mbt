///|
fn audit_entry() -> @registry.RegistryEntry {
  {
    behavior_id: "case:echo",
    command: "echo",
    owner: "commands/echo",
    surface: ["stdout"],
    status: "supported",
    implementation: "json-case",
    source: "tests/cases/echo.json",
    case_id: "echo",
    aliases: ["legacy-echo"],
    coverage: [],
    required_backends: ["native", "wasm"],
    platforms: [],
    required_evidence: ["contract", "backend-pair"],
    observations: ["status", "stdout"],
    oracle_profile: "",
  }
}

///|
fn audit_metadata(id : String) -> AuditRunMetadata {
  {
    schema: 1,
    run_id: id,
    git_revision: "1111111111111111111111111111111111111111",
    git_dirty: "false",
    toolchain: "moon-test",
    runner_version: "runner-test",
    registry_hash: @testkit.sha256_text("registry"),
    manifest_hash: @testkit.sha256_text("manifest"),
    case_corpus_hash: @testkit.sha256_text("corpus"),
    native_artifact_hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    wasm_artifact_hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    oracle_profile_id: "",
    oracle_image_digest: "",
    oracle_versions_hash: "",
    moonx_coordinates: [],
    platform: "macos",
    os: "Darwin",
    architecture: "arm64",
    locale: "C",
    timezone: "UTC",
    docker_version: "",
    policy_hash: @testkit.sha256_text("policy"),
    environment_fingerprint: @testkit.execution_environment_digest([
      {
        program: "fixture",
        inherit_env: true,
        values: { "LC_ALL": "C", "TZ": "UTC" },
      },
    ]),
    host_environment_fingerprint: @testkit.sha256_text("environment"),
    execution_environments: [
      {
        program: "fixture",
        inherit_env: true,
        values: { "LC_ALL": "C", "TZ": "UTC" },
      },
    ],
    started_at_ms: 1L,
    ended_at_ms: 2L,
    reproducibility_status: "complete",
  }
}

///|
fn audit_row(
  id : String,
  backend : String,
  verification : String,
) -> EvidenceRow {
  {
    id: "echo",
    result: "pass",
    verification,
    backend,
    platform: "macos",
    source_version: "workspace",
    observations: ["status", "stdout"],
    missing_observations: [],
    run_id: id,
    reproducibility_status: "complete",
    registry_revision: @testkit.sha256_text("registry"),
    oracle_profile_id: "",
    artifact_id: "native:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,wasm:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  }
}

///|
test "typed binding evidence never matches bare names across execution kinds" {
  let scenario = {
    ..audit_entry(),
    behavior_id: "stable-scenario",
    implementation: "stateful-scenario",
    source: "tests/runner/scenarios.mbt::shared",
    case_id: "",
    aliases: [],
  }
  let cohort = {
    ..scenario,
    behavior_id: "stable-cohort",
    implementation: "compatibility-cohort",
    source: "tests/runner/cohorts.mbt::shared",
  }
  assert_true(evidence_id_matches(scenario, "scenario:shared"))
  assert_false(evidence_id_matches(scenario, "shared"))
  assert_false(evidence_id_matches(cohort, "scenario:shared"))
  assert_true(evidence_id_matches(cohort, "cohort:shared"))
  assert_true(evidence_id_matches(audit_entry(), "legacy-echo"))
  assert_true(evidence_id_matches(audit_entry(), "echo"))
}

///|
test "Native and Wasm passing independently do not prove backend pairing" {
  let entry = audit_entry()
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let declaration = {
    ..declaration_for_test(entry.behavior_id, "pass"),
    coverage: [
      {
        ..declaration_for_test(entry.behavior_id, "pass").coverage[0],
        report: None,
        reports: Some(["native/summary.jsonl", "wasm/summary.jsonl"]),
      },
    ],
  }
  let bundles : Array[EvidenceBundle] = [
    {
      report_path: "native/summary.jsonl",
      metadata: audit_metadata("native"),
      rows: [audit_row("native", "native", "contract")],
      selected_ids: ["echo"],
      oracle_verified: false,
      published_coordinates: [],
    },
    {
      report_path: "wasm/summary.jsonl",
      metadata: audit_metadata("wasm"),
      rows: [audit_row("wasm", "wasm", "contract")],
      selected_ids: ["echo"],
      oracle_verified: false,
      published_coordinates: [],
    },
  ]
  let failures = validate_report_evidence(declaration, registry, bundles)
  assert_true(failures.any(value => value.contains("backend-pair")))
  assert_true(!failures.any(value => value.contains("lacks 'contract'")))
}

///|
test "paired observations are sufficient only for their own selected run" {
  let entry = audit_entry()
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let declaration = declaration_for_test(entry.behavior_id, "pass")
  let bundle : EvidenceBundle = {
    report_path: "summary.jsonl",
    metadata: audit_metadata("pair"),
    rows: [audit_row("pair", "native+wasm", "backend-pair")],
    selected_ids: ["echo"],
    oracle_verified: false,
    published_coordinates: [],
  }
  assert_true(
    validate_report_evidence(declaration, registry, [bundle]).is_empty(),
  )
  assert_true(
    !validate_report_evidence(declaration, registry, [
      { ..bundle, selected_ids: [], },
    ]).is_empty(),
  )
  assert_true(
    !validate_report_evidence(declaration, registry, [
      { ..bundle, rows: [{ ..bundle.rows[0], run_id: "different-run", }], },
    ]).is_empty(),
  )
}

///|
test "observations cannot be borrowed from a different verification row" {
  let entry = audit_entry()
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let declaration = declaration_for_test(entry.behavior_id, "pass")
  let bundle : EvidenceBundle = {
    report_path: "summary.jsonl",
    metadata: audit_metadata("pair"),
    rows: [
      {
        ..audit_row("pair", "native+wasm", "backend-pair"),
        observations: ["status"],
      },
      audit_row("pair", "native", "contract"),
    ],
    selected_ids: ["echo"],
    oracle_verified: false,
    published_coordinates: [],
  }
  assert_true(
    validate_report_evidence(declaration, registry, [bundle]).any(value => {
      value.contains("backend-pair")
    }),
  )
}

///|
test "upstream evidence needs matching sealed profile and immutable inventory" {
  let entry = {
    ..audit_entry(),
    oracle_profile: "pinned-v1",
    required_evidence: ["upstream-differential"],
  }
  let metadata = {
    ..audit_metadata("oracle"),
    oracle_profile_id: "pinned-v1",
    oracle_image_digest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    oracle_versions_hash: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  }
  let row = {
    ..audit_row("oracle", "native", "differential"),
    oracle_profile_id: "pinned-v1",
  }
  assert_true(
    row_proves(row, metadata, entry, "upstream-differential", "native", [
      "status", "stdout",
    ]),
  )
  assert_true(
    !row_proves(
      row,
      { ..metadata, oracle_image_digest: "mutable:tag", },
      entry,
      "upstream-differential",
      "native",
      [],
    ),
  )
  assert_true(
    !row_proves(
      row,
      metadata,
      { ..entry, oracle_profile: "another-profile", },
      "upstream-differential",
      "native",
      [],
    ),
  )
  assert_true(
    !verification_supports(
      { ..row, backend: "published-wasm", },
      "upstream-differential",
    ),
  )
  assert_true(!verification_supports(row, "published-differential"))
}

///|
test "platform exclusion uses POSIX membership without accepting an applicable skip" {
  let entry = { ..audit_entry(), platforms: ["posix"], }
  assert_true(platform_applies(entry, "macos"))
  assert_true(platform_applies(entry, "linux"))
  assert_true(!platform_applies(entry, "windows"))
  assert_true(
    !row_proves(
      { ..audit_row("pair", "native", "contract"), result: "skip", },
      audit_metadata("pair"),
      entry,
      "contract",
      "native",
      [],
    ),
  )
}

///|
test "dirty and mismatched fingerprints cannot prove the explicit committed head" {
  let metadata = audit_metadata("run")
  assert_true(
    validate_metadata(
      { ..metadata, architecture: "", },
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).any(item => item.contains("architecture")),
  )
  assert_true(
    validate_row_identity(
      { ..audit_row("run", "native", "contract"), artifact_id: "stale", },
      metadata,
    ).contains("mismatched artifact_id"),
  )
  assert_true(
    validate_metadata(
      metadata,
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).is_empty(),
  )
  assert_true(
    !validate_metadata(
      { ..metadata, git_dirty: "true", },
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).is_empty(),
  )
  assert_true(
    !validate_metadata(
      metadata,
      metadata.registry_hash,
      ["different-corpus"],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).is_empty(),
  )
  assert_true(
    !validate_metadata(
      metadata,
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      "other-head",
    ).is_empty(),
  )
}

///|
test "complete labels cannot hide missing policy or Docker provenance" {
  let metadata = audit_metadata("complete")
  let missing_policy = { ..metadata, policy_hash: "", }
  assert_true(
    validate_metadata(
      missing_policy,
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).any(message => message.contains("policy_hash")),
  )
  let oracle = {
    ..metadata,
    oracle_profile_id: "pinned-v1",
    oracle_image_digest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    oracle_versions_hash: @testkit.sha256_text("oracle inventory"),
    docker_version: "Docker protocol fixture",
  }
  assert_true(
    validate_metadata(
      oracle,
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).is_empty(),
  )
  assert_true(
    validate_metadata(
      { ..oracle, docker_version: "", },
      metadata.registry_hash,
      [metadata.case_corpus_hash],
      [metadata.manifest_hash],
      metadata.git_revision,
    ).any(message => message.contains("docker_version")),
  )
  for key in ["policy_hash", "docker_version"] {
    guard ToJson::to_json(oracle) is Object(fields) else {
      fail("run metadata must encode as an object")
    }
    fields.remove(key)
    let decoded : AuditRunMetadata? = Some(
      @json.from_json(Json::object(fields)),
    ) catch {
      _ => None
    }
    assert_true(decoded is None, msg="missing metadata field accepted: " + key)
  }
}

///|
test "canonical aliases cannot create duplicate claims and deferred still needs rejection rows" {
  let entry = {
    ..audit_entry(),
    status: "boundary",
    required_evidence: ["boundary"],
  }
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let declaration = {
    ..declaration_for_test(entry.behavior_id, "deferred"),
    required_evidence: ["boundary"],
    coverage: [
      {
        ..declaration_for_test(entry.behavior_id, "deferred").coverage[0],
        evidence: ["boundary"],
      },
    ],
    boundaries: [
      {
        behavior_id: "legacy-echo",
        support_record: "docs/compatibility.md",
        adr: "docs/adr.md",
        current_limit: "API absent",
        unlock_condition: "released public API",
      },
    ],
    deferred: [entry.behavior_id],
  }
  assert_true(validate_coverage(declaration, registry).is_empty())
  assert_true(!validate_report_evidence(declaration, registry, []).is_empty())
  assert_true(
    !validate_coverage(
      {
        ..declaration,
        coverage: [
          ..declaration.coverage,
          { ..declaration.coverage[0], behavior_id: "legacy-echo", },
        ],
      },
      registry,
    ).is_empty(),
  )
}
