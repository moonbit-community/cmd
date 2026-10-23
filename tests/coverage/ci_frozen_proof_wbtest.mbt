///|
priv struct FrozenProofFixture {
  binding : CiFrozenBinding
  registry : @registry.Registry
  cases : Array[@testkit.Case]
  coordinates : Map[String, String]
  bundle : EvidenceBundle
}

///|
fn frozen_proof_fixture() -> FrozenProofFixture raise {
  let contract : @testkit.Case = @json.from_json({
    "id": "frozen-version",
    "command": "echo",
    "args": ["--version"],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "comparison": "contract",
    "expected_stdout_text": "echo 0.2.1\n",
    "expected_stderr_text": "",
  })
  let differential = {
    ..contract,
    id: "frozen-bytes",
    command: "cat",
    args: [],
    comparison: Some("exact"),
    expected_stdout_text: None,
    expected_stderr_text: None,
  }
  let rejection = {
    ..contract,
    id: "frozen-rejection",
    command: "cp",
    args: [],
    comparison: Some("boundary"),
    expected_rejection: Some("source mode unavailable"),
    expected_stdout_text: None,
    expected_stderr_text: None,
    observe: Some(["mtime", "identity"]),
  }
  let windows = {
    ..rejection,
    id: "frozen-windows-rejection",
    command: "mv",
    observe: None,
    host_platforms: Some(["windows"]),
  }
  let cases = [contract, differential, rejection, windows]
  let entries = cases.map(fixture => {
    ..audit_entry(),
    behavior_id: "frozen-case:" + fixture.id,
    command: fixture.command,
    owner: "commands/" + fixture.command,
    source: "frozen/" + fixture.command + ".json",
    case_id: fixture.id,
    aliases: [],
    status: if fixture.expected_rejection is Some(_) {
      "boundary"
    } else {
      "supported"
    },
    required_evidence: if fixture.expected_rejection is Some(_) {
      ["boundary"]
    } else if fixture.id == "frozen-bytes" {
      ["upstream-differential"]
    } else {
      ["contract"]
    },
    observations: ["status"],
    platforms: fixture.host_platforms.unwrap_or([]),
    oracle_profile: if fixture.id == "frozen-bytes" {
      "pinned-oracle-v1"
    } else {
      ""
    },
  })
  let registry : @registry.Registry = {
    schema: 2,
    entries,
    release_commands: [],
  }
  let coordinates : Map[String, String] = Map([
    ("echo", "cli/echo@0.2.1"),
    ("cat", "cli/cat@0.2.1"),
    ("cp", "cli/cp@0.2.1"),
    ("mv", "cli/mv@0.2.3"),
  ])
  let binding = {
    ..ci_test_frozen(),
    coordinates: coordinates.values().collect(),
  }
  let metadata = {
    ..audit_metadata("frozen-run"),
    platform: "linux",
    os: "Linux",
    manifest_hash: binding.manifest_hash,
    case_corpus_hash: binding.corpus_hash,
    registry_hash: binding.registry_hash,
    native_artifact_hash: "",
    oracle_profile_id: "pinned-oracle-v1",
    oracle_image_digest: "sha256:" + "c".repeat(64),
    oracle_versions_hash: "d".repeat(64),
    docker_version: "docker-fixture",
    moonx_coordinates: binding.coordinates,
  }
  let rows = cases.map(fixture => {
    ..audit_row(metadata.run_id, "published-wasm", "contract"),
    id: fixture.id,
    platform: "linux",
    source_version: coordinates[fixture.command],
    registry_revision: binding.registry_hash,
    oracle_profile_id: metadata.oracle_profile_id,
    artifact_id: "wasm:" + metadata.wasm_artifact_hash,
    result: if fixture.id == windows.id {
      "skip"
    } else {
      "pass"
    },
    verification: if fixture.id == differential.id {
      "differential"
    } else if fixture.expected_rejection is Some(_) {
      "boundary"
    } else {
      "contract"
    },
    observations: match fixture.id {
      "frozen-version" => ["status", "stdout", "stderr"]
      "frozen-bytes" => ["status", "stdout", "stderr", "content", "type"]
      "frozen-rejection" =>
        [
          "status", "nonzero-status", "diagnostic", "stderr", "content", "type",
          "mtime", "identity",
        ]
      _ => []
    },
  })
  {
    binding,
    registry,
    cases,
    coordinates,
    bundle: {
      report_path: @path.Path("linux/published-differential/summary.jsonl")
      .normalize()
      .to_string(),
      metadata,
      rows,
      selected_ids: cases.map(fixture => fixture.id),
      oracle_verified: true,
      published_coordinates: binding.coordinates,
    },
  }
}

///|
fn frozen_proof_errors(
  fixture : FrozenProofFixture,
  bundle : EvidenceBundle,
) -> Array[String] {
  ci_frozen_publication_errors(
    fixture.binding,
    fixture.registry,
    fixture.cases,
    fixture.coordinates,
    bundle,
  )
}

///|
async test "CI frozen network oracle scenarios require their delegated observations without invented file types" {
  let mut corpus_path = ""
  for
    path in [
      "tests/release_runner/current/published.json.cases.json", "release_runner/current/published.json.cases.json",
      "../release_runner/current/published.json.cases.json",
    ] {
    if @fs.exists(path) {
      corpus_path = path
      break
    }
  }
  guard corpus_path != "" else {
    fail("missing frozen publication fixture corpus")
  }
  let fixtures = @testkit.load_cases(corpus_path)
  guard fixtures
    .iter()
    .find_first(fixture => fixture.id == "network-auth-cookie-oracle")
    is Some(network) else {
    fail("the frozen network oracle scenario is missing")
  }
  assert_eq(network.command, "curl")
  assert_eq(network.comparison, Some("oracle-scenario"))
  let base = frozen_proof_fixture()
  let observations = @network_scenarios.observations(network.id)
  assert_false(observations.contains("type"))
  assert_true(observations.contains("request-authorization"))
  assert_true(observations.contains("cookie-effects"))
  let coordinate = "cli/curl@0.2.3"
  let binding = { ..base.binding, coordinates: [coordinate], }
  let entry = {
    ..base.registry.entries[1],
    behavior_id: "case:" + network.id,
    command: network.command,
    owner: "commands/curl",
    source: "frozen/network.json",
    case_id: network.id,
  }
  let metadata = { ..base.bundle.metadata, moonx_coordinates: [coordinate], }
  let row = {
    ..base.bundle.rows[1],
    id: network.id,
    source_version: coordinate,
    observations,
  }
  let fixture : FrozenProofFixture = {
    binding,
    registry: { ..base.registry, entries: [entry], },
    cases: [network],
    coordinates: Map([("curl", coordinate)]),
    bundle: {
      ..base.bundle,
      metadata,
      rows: [row],
      selected_ids: [network.id],
      published_coordinates: [coordinate],
    },
  }
  assert_true(frozen_proof_errors(fixture, fixture.bundle).is_empty())
  for missing in ["request-authorization", "cookie-effects"] {
    assert_false(
      frozen_proof_errors(fixture, {
        ..fixture.bundle,
        rows: [
          { ..row, observations: observations.filter(item => item != missing), },
        ],
      }).is_empty(),
    )
  }
  assert_false(
    frozen_proof_errors(base, {
      ..base.bundle,
      rows: base.bundle.rows.map(row => {
        if row.id == "frozen-bytes" {
          {
            ..row,
            observations: row.observations.filter(item => item != "type"),
          }
        } else {
          row
        }
      }),
    }).is_empty(),
  )
}

///|
test "CI frozen publication proves contracts rejections and differentials as a separate subject" {
  let fixture = frozen_proof_fixture()
  assert_true(frozen_proof_errors(fixture, fixture.bundle).is_empty())
  assert_true(
    ci_frozen_metadata_matches(
      {
        ..fixture.bundle.metadata,
        moonx_coordinates: [
          "cli/mv@0.2.3", "cli/cp@0.2.1", "cli/cat@0.2.1", "cli/echo@0.2.1",
        ],
      },
      fixture.binding,
    ),
  )
  let current = {
    ..audit_entry(),
    behavior_id: "frozen-case:frozen-version",
    case_id: "frozen-version",
    source: "current/echo.json",
    required_evidence: ["contract"],
  }
  let declaration = {
    ..declaration_for_test(current.behavior_id, "pass"),
    coverage: [
      {
        ..declaration_for_test(current.behavior_id, "pass").coverage[0],
        report: Some(fixture.bundle.report_path),
        backends: ["wasm"],
        evidence: ["contract"],
      },
    ],
  }
  // Even an unchanged stable ID cannot make a published row prove current source.
  assert_false(
    validate_report_evidence(
      declaration,
      { schema: 2, entries: [current], release_commands: [], },
      [fixture.bundle],
    ).is_empty(),
  )
}

///|
test "CI frozen publication rejects empty partial duplicated and current source rows" {
  let fixture = frozen_proof_fixture()
  let bundle = fixture.bundle
  for
    changed in [
      { ..bundle, rows: [], },
      { ..bundle, rows: bundle.rows.filter(row => row.id != "frozen-bytes"), },
      {
        ..bundle,
        rows: [bundle.rows[0], bundle.rows[0], bundle.rows[2], bundle.rows[3]],
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-version" {
            { ..row, backend: "wasm", source_version: "workspace", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-version" {
            { ..row, id: "frozen-case:frozen-version", }
          } else {
            row
          }
        }),
      },
      { ..bundle, selected_ids: ["frozen-version"], },
      { ..bundle, rows: bundle.rows + [bundle.rows[0]], },
    ] {
    assert_false(frozen_proof_errors(fixture, changed).is_empty())
  }
}

///|
test "CI frozen publication requires complete coordinates immutable oracle and exact identities" {
  let fixture = frozen_proof_fixture()
  let bundle = fixture.bundle
  for
    changed in [
      {
        ..bundle,
        metadata: { ..bundle.metadata, moonx_coordinates: ["cli/echo@0.2.1"], },
      },
      {
        ..bundle,
        metadata: {
          ..bundle.metadata,
          moonx_coordinates: bundle.metadata.moonx_coordinates +
          ["cli/echo@0.2.1"],
        },
      },
      { ..bundle, published_coordinates: ["cli/echo@0.2.1"], },
      { ..bundle, oracle_verified: false, },
      {
        ..bundle,
        metadata: {
          ..bundle.metadata,
          native_artifact_hash: "f".repeat(64),
          wasm_artifact_hash: "",
        },
        rows: bundle.rows.map(row => {
          ..row,
          artifact_id: "native:" + "f".repeat(64),
        }),
      },
      { ..bundle, metadata: { ..bundle.metadata, git_dirty: "true", }, },
      {
        ..bundle,
        metadata: { ..bundle.metadata, reproducibility_status: "partial", },
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            { ..row, source_version: "cli/cat@9.9.9", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            {
              ..row,
              registry_revision: @testkit.sha256_text("current-registry"),
            }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            { ..row, artifact_id: "wasm:" + "e".repeat(64), }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            { ..row, run_id: "another-run", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            { ..row, missing_observations: ["stdout"], }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-bytes" {
            { ..row, observations: ["status"], }
          } else {
            row
          }
        }),
      },
    ] {
    assert_false(frozen_proof_errors(fixture, changed).is_empty())
  }
}

///|
test "CI frozen zero-status upstream fixtures still require actual rejection and explicit platform skips" {
  let fixture = frozen_proof_fixture()
  let bundle = fixture.bundle
  assert_eq(fixture.cases[2].expected_status, 0)
  for
    changed in [
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-rejection" {
            { ..row, verification: "contract", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-rejection" {
            { ..row, verification: "availability", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-rejection" {
            {
              ..row,
              observations: row.observations.filter(item => {
                item != "nonzero-status"
              }),
            }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-rejection" {
            { ..row, result: "skip", }
          } else {
            row
          }
        }),
      },
      {
        ..bundle,
        rows: bundle.rows.map(row => {
          if row.id == "frozen-windows-rejection" {
            { ..row, result: "pass", }
          } else {
            row
          }
        }),
      },
    ] {
    assert_false(frozen_proof_errors(fixture, changed).is_empty())
  }
}

///|
async test "CI frozen case selection reads immutable bodies aliases and unconditional extras" {
  let root = @fs.tmpdir(prefix="mooncmd-frozen-proof-selection-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let original = frozen_proof_fixture().cases[0]
  let selected = { ..original, aliases: Some(["legacy-version"]), }
  let excluded = { ..original, id: "not-selected", }
  let extra = { ..original, id: "unconditional-extra", }
  @fs.write_file(
    root + "/immutable.json",
    @testkit.canonical_json({
      "cases": [ToJson::to_json(selected), ToJson::to_json(excluded)],
    }),
  )
  @fs.write_file(
    root + "/current.json",
    @testkit.canonical_json({
      "cases": [
        ToJson::to_json({
          ..selected,
          expected_stdout_text: Some("echo 9.9.9\n"),
        }),
      ],
    }),
  )
  let binding = { ..ci_test_frozen(), corpus_path: root + "/immutable.json", }
  @fs.write_file(
    root + "/manifest.json",
    @testkit.canonical_json({
      "base_manifest": "current.json",
      "case_ids": ["legacy-version"],
      "extra_cases": [ToJson::to_json(extra)],
    }),
  )
  let cases = ci_frozen_cases(root + "/manifest.json", binding)
  assert_eq(cases.map(fixture => fixture.id), [
    "unconditional-extra", "frozen-version",
  ])
  assert_eq(cases[1].expected_stdout_text, Some("echo 0.2.1\n"))
  @fs.write_file(
    root + "/manifest.json",
    @testkit.canonical_json({
      "case_ids": [],
      "extra_cases": [ToJson::to_json(extra)],
    }),
  )
  assert_eq(ci_frozen_cases(root + "/manifest.json", binding).length(), 3)
  @fs.write_file(
    root + "/manifest.json",
    "{\"case_ids\":[\"unknown\"],\"extra_cases\":[]}",
  )
  assert_true(
    try {
      ignore(ci_frozen_cases(root + "/manifest.json", binding))
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "CI published extras reference only canonically identical frozen cases" {
  let root = @fs.tmpdir(prefix="mooncmd-frozen-extra-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture = frozen_proof_fixture()
  let body = fixture.cases[1]
  let entry = { ..fixture.registry.entries[1], source: "current.json", }
  let registry : @registry.Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let corpus : Json = { "cases": [ToJson::to_json(body)] }
  @fs.write_file(root + "/current.json", @testkit.canonical_json(corpus))
  @fs.write_file(root + "/frozen.json", @testkit.canonical_json(corpus))
  let binding = { ..fixture.binding, corpus_path: root + "/frozen.json", }
  let requirement = {
    ..ci_scope_test_requirement(entry),
    evidence: ["published-differential"],
    backends: ["wasm"],
    platforms: ["linux"],
  }
  let intent = ci_scope_test_intent([requirement], [])
  let impact = ci_scope_impact(intent, registry=Some(registry))
  let identical = ci_frozen_selected_ids(binding, registry, root)
  assert_eq(identical, [body.id])
  let declaration = ci_declaration(
    impact,
    registry,
    [fixture.bundle.report_path],
    frozen_reports=[fixture.bundle.report_path],
    identical_frozen_cases=identical,
  )
  assert_eq(declaration.coverage[0].reports, Some([fixture.bundle.report_path]))
  assert_eq(
    validate_scope_requirements(
      intent,
      declaration,
      registry,
      [fixture.bundle],
      ["linux"],
    ),
    [],
  )
  @fs.write_file(
    root + "/current.json",
    @testkit.canonical_json({
      "cases": [
        ToJson::to_json({
          ..body,
          expected_stdout_text: Some("changed current bytes\n"),
        }),
      ],
    }),
  )
  let changed = ci_frozen_selected_ids(binding, registry, root)
  assert_eq(changed, [])
  let changed_declaration = ci_declaration(
    impact,
    registry,
    [fixture.bundle.report_path],
    frozen_reports=[fixture.bundle.report_path],
    identical_frozen_cases=changed,
  )
  assert_eq(changed_declaration.coverage[0].reports, Some([]))
  assert_false(
    validate_scope_requirements(
      intent,
      changed_declaration,
      registry,
      [fixture.bundle],
      ["linux"],
    ).is_empty(),
  )
  assert_true(frozen_proof_errors(fixture, fixture.bundle).is_empty())
}
