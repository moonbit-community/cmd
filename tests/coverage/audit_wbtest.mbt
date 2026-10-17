///|
fn declaration_for_test(
  behavior_id : String,
  result : String,
) -> ChangeDeclaration {
  {
    schema: 1,
    affected_commands: ["echo"],
    affected_behaviors: [behavior_id],
    affected_options: Some([]),
    affected_operands: Some([]),
    case_ids: Some([]),
    core_impact: None,
    published_manifest_affected: Some(false),
    required_backends: ["native", "wasm"],
    required_evidence: ["contract", "backend-pair"],
    required_observations: ["status", "stdout"],
    coverage: [
      {
        behavior_id,
        backends: ["native", "wasm"],
        evidence: ["contract", "backend-pair"],
        observations: ["status", "stdout"],
        result,
        report: Some("summary.jsonl"),
        reports: None,
      },
    ],
    boundaries: [],
    deferred: [],
    uncovered: None,
  }
}

///|
test "declaration rejects invalid coverage result" {
  let declaration = declaration_for_test("case:echo", "failed")
  let failures = validate_declaration_shape(declaration)
  assert_true(failures.any(item => item.contains("must be pass or deferred")))
}

///|
test "coverage requires every declared behavior" {
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [
      {
        behavior_id: "case:echo",
        command: "echo",
        owner: "commands/echo",
        surface: ["stdout"],
        status: "supported",
        implementation: "json-case",
        source: "../cases/echo.json",
        case_id: "echo",
        aliases: [],
        coverage: [],
        required_backends: ["native", "wasm"],
        platforms: [],
        required_evidence: ["contract", "backend-pair"],
        observations: ["status", "stdout"],
        oracle_profile: "",
      },
    ],
  }
  let declaration = declaration_for_test("case:echo", "pass")
  assert_true(validate_coverage(declaration, registry).is_empty())
  assert_true(
    validate_coverage({ ..declaration, coverage: [], }, registry).any(item => {
      item.contains("missing evidence")
    }),
  )
}

///|
test "boundary requires support record and unlock condition" {
  let declaration = {
    ..declaration_for_test("case:echo", "pass"),
    boundaries: [
      {
        behavior_id: "case:echo",
        support_record: "",
        adr: "",
        current_limit: "",
        unlock_condition: "",
      },
    ],
  }
  assert_true(
    validate_declaration_shape(declaration).any(item => {
      item.contains("boundary requires")
    }),
  )
}

///|
test "audit rejects untyped claims and empty report paths" {
  let declaration = declaration_for_test("case:echo", "pass")
  let record = {
    ..declaration.coverage[0],
    evidence: ["availability"],
    report: Some(""),
  }
  let failures = validate_declaration_shape({
    ..declaration,
    coverage: [record],
  })
  assert_true(
    failures.any(item => {
      item.contains("unsupported backend, evidence, or observation")
    }),
  )
  assert_true(failures.any(item => item.contains("nonempty paths")))
}

///|
test "audit requires changed registered sources and published manifest impact" {
  let first = audit_entry()
  let second = {
    ..first,
    behavior_id: "case:other",
    case_id: "other",
    source: "tests/cases/other.json",
    aliases: [],
  }
  let registry : @registry.Registry = {
    schema: 2,
    entries: [first, second],
    release_commands: [],
  }
  let (_, _, failures) = validate_changed_scope(
    ["tests/cases/other.json", "tests/release_runner/published-test.json"],
    declaration_for_test(first.behavior_id, "pass"),
    registry,
  )
  assert_true(
    failures.any(item => item.contains("changed registered test source")),
  )
  assert_true(
    failures.any(item => item.contains("published_manifest_affected true")),
  )
  for
    path in [
      "tests/release_runner/current/published.json", "tests/release_runner/current/published-cases.json",
      "tests/release_runner/historical/published-test.json", "tests/release_runner/historical/published-test.cases.json",
    ] {
    let (_, _, rejected) = validate_changed_scope(
      [path],
      declaration_for_test(first.behavior_id, "pass"),
      registry,
    )
    assert_true(
      rejected.any(item => item.contains("published_manifest_affected true")),
    )
    let declared = {
      ..declaration_for_test(first.behavior_id, "pass"),
      published_manifest_affected: Some(true),
    }
    let (_, _, accepted) = validate_changed_scope([path], declared, registry)
    assert_false(
      accepted.any(item => item.contains("published_manifest_affected true")),
    )
  }
}
