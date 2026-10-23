///|
fn intent_fixture_selection() -> Selection {
  {
    mode: "docs",
    reasons: ["new narrative report"],
    changed_paths: ["docs/reports/new/README.md"],
    commands: [],
    behaviors: [],
    packages: [],
    core_packages: [],
    build_prerequisites: [],
    case_ids: [],
    published_coordinates: [],
    affected_options: [],
    affected_operands: [],
    requirements: [],
  }
}

///|
fn intent_fixture() -> ScopeIntent {
  let digest = "a".repeat(64)
  let selection = intent_fixture_selection()
  {
    schema: 2,
    transition: "shadow-full",
    policy_version: scope_policy_version,
    target_ref: "origin/main",
    base: "b".repeat(40),
    payload: digest,
    change_set: digest,
    changes: [],
    identities: {
      base_policy: digest,
      candidate_policy: digest,
      base_graph: digest,
      candidate_graph: digest,
      base_registry: digest,
      candidate_registry: digest,
      base_associations: digest,
      candidate_associations: digest,
    },
    automatic: selection,
    extras: [],
    selection,
    boundaries: [],
    deferred: [],
    uncovered: [],
  }
}

///|
test "scope intent rejects outcomes unknown nested fields and ambiguous JSON keys" {
  let intent = intent_fixture()
  assert_eq(parse_intent(intent.to_json()), intent)
  for
    raw in [
      "{\"schema\":2,\"schema\":1}", "{\"schema\":2,\"\\u0073chema\":2}", "{\"outer\":[{\"result\":1,\"result\":2}]}",
    ] {
    try strict_json(raw) catch {
      _ => ()
    } noraise {
      _ => fail("duplicate keys must be rejected")
    }
  }
  assert_eq(
    strict_json("[{\"x\":1},{\"x\":2}]"),
    @json.parse("[{\"x\":1},{\"x\":2}]"),
  )
  for field in ["result", "report", "timestamp", "head", "run_id"] {
    guard intent.to_json() is Object(fields) else {
      fail("fixture must be an object")
    }
    fields[field] = Json("forged")
    try parse_intent(Json::object(fields)) catch {
      _ => ()
    } noraise {
      _ => fail("execution fields must be rejected")
    }
  }
  guard intent.to_json() is Object(fields) else {
    fail("fixture must be an object")
  }
  guard fields["selection"] is Object(selected) else {
    fail("fixture selection must be an object")
  }
  selected["reports"] = []
  fields["selection"] = Json::object(selected)
  try parse_intent(Json::object(fields)) catch {
    _ => ()
  } noraise {
    _ => fail("nested report claims must fail")
  }
}

///|
test "scope freshness binds payload complete diff dependencies policy and target base" {
  let expected = intent_fixture()
  let different = "c".repeat(64)
  for
    stale in [
      { ..expected, payload: different, },
      { ..expected, change_set: different, },
      { ..expected, base: "c".repeat(40), },
      {
        ..expected,
        identities: { ..expected.identities, candidate_graph: different, },
      },
      {
        ..expected,
        identities: { ..expected.identities, base_graph: different, },
      },
      {
        ..expected,
        identities: { ..expected.identities, candidate_policy: different, },
      },
      {
        ..expected,
        identities: { ..expected.identities, candidate_registry: different, },
      },
      {
        ..expected,
        identities: {
          ..expected.identities,
          candidate_associations: different,
        },
      },
    ] {
    assert_false(freshness_errors(stale, expected).is_empty())
    // Reformatting an unchanged declaration cannot repair any stale identity.
    let reparsed = parse_intent_text(
      " \n" + @testkit.canonical_json(stale.to_json()) + "\n ",
    )
    assert_false(freshness_errors(reparsed, expected).is_empty())
  }
  assert_true(
    freshness_errors(
      expected,
      parse_intent_text(
        "\n " + @testkit.canonical_json(expected.to_json()) + " \n",
      ),
    ).is_empty(),
  )
}

///|
test "scope freshness retains human additions and forbids an empty scope masquerade" {
  let base = intent_fixture()
  let extra : HumanExtra = {
    reason: "indirect fixture consumer",
    commands: ["cat"],
    behaviors: ["case:cat"],
    packages: ["commands/cat"],
    case_ids: ["cat"],
    backends: [],
    evidence: [],
    observations: [],
  }
  let selected : Selection = {
    ..base.selection,
    mode: "scoped",
    commands: ["cat"],
    behaviors: ["case:cat"],
    packages: ["commands/cat"],
    requirements: [
      {
        behavior_id: "case:cat",
        case_id: "cat",
        command: "cat",
        backends: ["native", "wasm"],
        evidence: ["contract"],
        observations: ["stdout"],
        platforms: ["all"],
        oracle_profile: "",
      },
    ],
  }
  let reviewed = { ..base, selection: selected, extras: [extra], }
  assert_eq(parse_intent(reviewed.to_json()), reviewed)
  assert_false(
    freshness_errors({ ..reviewed, extras: [], }, reviewed).is_empty(),
  )
  assert_false(
    freshness_errors({ ..reviewed, selection: base.selection, }, reviewed).is_empty(),
  )
  for
    invalid in [
      { ..reviewed, selection: { ..selected, mode: "docs", }, },
      { ..reviewed, selection: { ..selected, requirements: [], }, },
      { ..reviewed, extras: [{ ..extra, reason: " ", }], },
    ] {
    try parse_intent(invalid.to_json()) catch {
      _ => ()
    } noraise {
      _ => fail("invalid scope must fail")
    }
  }
}
