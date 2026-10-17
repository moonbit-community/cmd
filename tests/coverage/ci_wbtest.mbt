///|
fn ci_test_context() -> CiContext {
  {
    event: "pull_request",
    base: "2222222222222222222222222222222222222222",
    head: "1111111111111111111111111111111111111111",
    pr_head: "3333333333333333333333333333333333333333",
    run_id: "42",
    attempt: "2",
  }
}

///|
fn ci_test_impact(id : String) -> CiImpact {
  {
    schema: 1,
    affected_commands: [],
    affected_behaviors: [id],
    affected_options: [],
    affected_operands: [],
    case_ids: [],
    core_impact: None,
    published_manifest_affected: false,
    required_backends: [],
    required_evidence: [],
    required_observations: [],
    boundaries: [],
    deferred: [],
    uncovered: [],
    harness_bindings: [],
  }
}

///|
test "CI change ranges require the exact PR merge parents and push before commit" {
  let context = ci_test_context()
  assert_true(
    ci_context_errors(context, [context.base, context.pr_head]).is_empty(),
  )
  assert_false(
    ci_context_errors(context, [context.pr_head, context.base]).is_empty(),
  )
  assert_false(ci_context_errors(context, [context.base]).is_empty())
  assert_false(
    ci_context_errors({ ..context, head: "main", }, [
      context.base,
      context.pr_head,
    ]).is_empty(),
  )
  assert_true(ci_context_errors({ ..context, event: "push", }, []).is_empty())
  assert_false(
    ci_context_errors({ ..context, event: "push", base: "", }, []).is_empty(),
  )
  assert_false(
    ci_context_errors({ ..context, event: "push", base: context.head, }, []).is_empty(),
  )
  assert_true(
    ci_context_errors({ ..context, event: "schedule", base: "", }, []).is_empty(),
  )
  assert_false(
    ci_context_errors({ ..context, event: "schedule", }, []).is_empty(),
  )
}

///|
test "CI receipts reject another run source platform or future attempt" {
  let context = ci_test_context()
  assert_true(
    ci_receipt_context_errors({ ..context, attempt: "1", }, context).is_empty(),
  )
  assert_false(
    ci_receipt_context_errors({ ..context, attempt: "3", }, context).is_empty(),
  )
  assert_false(
    ci_receipt_context_errors({ ..context, run_id: "41", }, context).is_empty(),
  )
  assert_false(
    ci_receipt_context_errors({ ..context, head: context.base, }, context).is_empty(),
  )
  assert_true(
    ci_bundle_errors(audit_metadata("native"), context, "macos").is_empty(),
  )
  assert_false(
    ci_bundle_errors(audit_metadata("native"), context, "windows").is_empty(),
  )
  assert_false(
    ci_bundle_errors(
      { ..audit_metadata("native"), git_dirty: "true", },
      context,
      "macos",
    ).is_empty(),
  )
}

///|
test "CI impact rejects supplied outcomes and keeps documentation exclusions narrow" {
  let fields : Map[String, Json] = {
    "schema": 1,
    "affected_commands": [],
    "affected_behaviors": ["package-test:fixture"],
    "affected_options": [],
    "affected_operands": [],
    "case_ids": [],
    "published_manifest_affected": false,
    "required_backends": [],
    "required_evidence": [],
    "required_observations": [],
    "boundaries": [],
    "deferred": [],
    "uncovered": [],
    "harness_bindings": [],
  }
  assert_eq(ci_impact(Json::object(fields)).affected_behaviors, [
    "package-test:fixture",
  ])
  for key in ["coverage", "reports", "result", "pass"] {
    let claimed = fields.copy()
    claimed[key] = Json::string("pass")
    try ci_impact(Json::object(claimed)) catch {
      error => assert_true(error.to_string().contains("execution claim"))
    } noraise {
      _ => fail("CI intent accepted an execution claim")
    }
  }
  assert_true(ci_documentation_path("docs/reports/release/README.md"))
  for
    path in [
      "commands/echo/README.md", "AGENTS.md", "docs/compatibility.md", "docs/adr/0001-evidence.md",
      "docs/reports/release/prepare.mbtx", "docs/reports/release/contract.mbt.md",
      "docs/reports/release/manifest.json", "docs/reports/release/change.json", "docs/reports/release/evidence/result.json",
      "docs/reports/release/evidence/summary.jsonl", "tests/registry/registry.json",
      ".github/workflows/check.yml",
    ] {
    assert_false(ci_documentation_path(path))
  }
}

///|
test "CI harness-only impact needs reviewed bindings and real evidence without dummy commands" {
  let entry = {
    ..audit_entry(),
    behavior_id: "package-test:tests/coverage/fixture_wbtest.mbt::gate",
    command: "",
    implementation: "package-test",
    source: "tests/coverage/fixture_wbtest.mbt::gate",
    case_id: "",
    aliases: [],
    required_backends: ["native"],
    required_evidence: ["contract"],
    observations: ["status"],
  }
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry],
  }
  let paths = ["tests/coverage/entry.mbt", "tests/coverage/ci-change.json"]
  let impact = ci_test_impact(entry.behavior_id)
  assert_false(ci_scope_errors(paths, impact, registry).is_empty())
  let impact = {
    ..impact,
    harness_bindings: [{ path: paths[0], behavior_ids: [entry.behavior_id], }],
  }
  assert_true(ci_scope_errors(paths, impact, registry).is_empty())
  assert_false(ci_scope_errors([paths[0]], impact, registry).is_empty())
  let declaration = ci_declaration(impact, registry, ["native/summary.jsonl"])
  assert_eq(declaration.coverage[0].result, "required")
  assert_true(validate_declaration_shape(declaration, ci=true).is_empty())
  assert_false(validate_declaration_shape(declaration).is_empty())
  assert_true(validate_coverage(declaration, registry, ci=true).is_empty())
  assert_false(
    validate_report_evidence(declaration, registry, [], platforms=[
      "linux", "macos", "windows",
    ]).is_empty(),
  )
  let (_, _, product_failures) = validate_changed_scope(
    ["commands/echo/main.mbt"],
    declaration,
    registry,
  )
  assert_true(
    product_failures.any(failure => {
      failure.contains("missing from affected_commands")
    }),
  )
  let frozen = {
    ..impact,
    harness_bindings: [],
    published_manifest_affected: true,
  }
  assert_true(
    ci_scope_errors(
      [
        "tests/coverage/ci-change.json", "tests/release_runner/historical/published-old.json.sources/hash.json",
      ],
      frozen,
      registry,
    ).is_empty(),
  )
  for
    path in [
      "tests/release_runner/historical/prepare.mbtx", "tests/release_runner/historical/published-old.mbt",
      "tests/release_runner/current/published-helper.mbt",
    ] {
    assert_false(
      ci_scope_errors(["tests/coverage/ci-change.json", path], frozen, registry).is_empty(),
    )
  }
}

///|
test "CI coverage requires every applicable platform rather than any passing host" {
  let entry = audit_entry()
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry],
  }
  let platforms = ["linux", "macos", "windows"]
  let reports = platforms.map(platform => "./" + platform + "/summary.jsonl")
  let declaration = {
    ..declaration_for_test(entry.behavior_id, "pass"),
    coverage: [
      {
        ..declaration_for_test(entry.behavior_id, "pass").coverage[0],
        report: None,
        reports: Some(reports),
      },
    ],
  }
  let bundles : Array[EvidenceBundle] = platforms.map(platform => {
    // Loaded report paths use the host syntax, independently of evidence platform.
    report_path: @path.Path(platform + "/summary.jsonl").normalize().to_string(),
    metadata: { ..audit_metadata(platform), platform, },
    rows: [{ ..audit_row(platform, "native+wasm", "backend-pair"), platform, }],
    selected_ids: ["echo"],
    oracle_verified: false,
    published_coordinates: [],
  })
  assert_true(
    validate_report_evidence(declaration, registry, bundles, platforms~).is_empty(),
  )
  let missing = { ..bundles[2], rows: [], }
  assert_true(
    validate_report_evidence(declaration, registry, [
      bundles[0],
      bundles[1],
      missing,
    ]).is_empty(),
  )
  let failures = validate_report_evidence(
    declaration,
    registry,
    [bundles[0], bundles[1], missing],
    platforms~,
  )
  assert_true(failures.any(failure => failure.contains("platform 'windows'")))
  let posix : @registry.Registry = {
    ..registry,
    entries: [{ ..entry, platforms: ["posix"], }],
  }
  assert_true(
    validate_report_evidence(
      declaration,
      posix,
      [bundles[0], bundles[1], missing],
      platforms~,
    ).is_empty(),
  )
  assert_eq(evidence_platforms(entry, "upstream-differential", platforms), [
    "linux",
  ])
}
