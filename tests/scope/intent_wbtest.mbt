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
fn intent_closure_tree(
  registry : @registry.Registry,
  associations : String,
) -> TreeSnapshot {
  sel_test_tree(
    associations~,
    published="{\"schema\":2,\"commands\":[{\"name\":\"cat\",\"package_name\":\"cli/cat\",\"version\":\"0.2.1\",\"published\":true},{\"name\":\"sh\",\"package_name\":\"cli/sh\",\"version\":\"0.2.1\",\"published\":true}]}",
    files=[
      sel_test_file(
        "tests/registry/registry.json",
        content=@testkit.canonical_json(registry.to_json()),
      ),
      sel_test_file("docs/compatibility.md", content="current support"),
      sel_test_file("docs/adr/0001-evidence.md", content="current decision"),
      sel_test_file(
        "tests/registry/boundaries.json",
        content="{\"schema\":1,\"entries\":[{\"behavior_id\":\"sh-ordinary\",\"support_record\":\"docs/compatibility.md\",\"adr\":\"docs/adr/0001-evidence.md\",\"current_limit\":\"explicit rejection\",\"unlock_condition\":\"prove replacement\",\"rejection_tests\":[\"sh-ordinary\"],\"replacement_behaviors\":[]}]}",
      ),
    ],
  )
}

///|
fn intent_closure_review(
  tree : TreeSnapshot,
  graph : DependencyGraph,
  extra : HumanExtra,
  boundaries~ : Array[ScopeBoundary] = [],
) -> ScopeIntent raise {
  make_intent(
    "origin/main",
    "b".repeat(40),
    tree,
    tree,
    [],
    graph,
    graph,
    [extra],
    boundaries~,
  )
}

///|
fn intent_reviewed_closure_regression() -> Unit raise {
  let metadata = {
    ..sel_test_entry("metadata:cat", "cat"),
    owner: "tests/metadata/verify.mbtx",
    source: "tests/metadata/verify.mbtx::cat",
    implementation: "metadata-probe",
    required_backends: ["native"],
    required_evidence: ["contract"],
  }
  let child = {
    ..sel_test_entry("scenario:child", "curl"),
    owner: "tests/integration",
    source: "tests/integration/scenarios.mbt::child",
    implementation: "stateful-scenario",
    required_backends: ["native"],
    required_evidence: ["contract"],
    platforms: ["windows"],
  }
  let published = {
    ..sel_test_entry("case:published-child", "sh"),
    implementation: "json-case",
    source: "tests/cases/sh.json",
    case_id: "published-child",
    required_backends: ["wasm"],
    required_evidence: ["published-differential"],
    oracle_profile: "published-profile",
  }
  let retired = sel_test_entry("retired", "cat")
  let rejection = sel_test_entry("rejection", "cat")
  let ordinary_sh = {
    ..sel_test_entry("sh-ordinary", "sh"),
    status: "boundary",
    required_backends: ["native"],
    required_evidence: ["boundary"],
  }
  let registry = sel_test_registry([
    metadata,
    sel_test_entry("cat-ordinary", "cat"),
    ordinary_sh,
    sel_test_entry("wc-ordinary", "wc"),
    child,
    published,
    retired,
    rejection,
  ])
  let graph = sel_test_graph(
    [
      "commands/cat", "commands/curl", "commands/sh", "commands/wc", "core/stream",
      "core/process", "tests/metadata", "tests/integration",
    ],
    links=[("commands/cat", "core/stream"), ("commands/sh", "core/process")],
  )
  let associations = "{\"schema\":1,\"rules\":[{\"id\":\"children\",\"kind\":\"scenario\",\"trigger_commands\":[\"cat\"],\"trigger_paths\":[],\"behavior_ids\":[\"scenario:child\",\"case:published-child\"],\"build_commands\":[\"sh\",\"wc\"],\"full\":false}]}"
  let tree = intent_closure_tree(registry, associations)
  let extra : HumanExtra = {
    reason: "reviewed indirect execution",
    commands: [],
    behaviors: [],
    packages: [],
    case_ids: [],
    backends: [],
    evidence: [],
    observations: [],
  }
  let metadata_only = intent_closure_review(tree, graph, {
    ..extra,
    behaviors: [metadata.behavior_id],
  })
  assert_eq(metadata_only.automatic.mode, "docs")
  assert_eq(metadata_only.selection.behaviors, [metadata.behavior_id])
  assert_true(
    metadata_only.selection.build_prerequisites.contains("commands/cat"),
  )
  assert_true(
    metadata_only.selection.build_prerequisites.contains("core/stream"),
  )
  assert_true(
    !metadata_only.selection.published_coordinates.contains("cli/sh@0.2.1"),
  )
  let scenario_only = intent_closure_review(tree, graph, {
    ..extra,
    behaviors: [child.behavior_id],
  })
  assert_eq(scenario_only.selection.commands, ["curl"])
  assert_eq(scenario_only.selection.behaviors, [child.behavior_id])
  for root in ["commands/curl", "commands/sh", "commands/wc", "core/process"] {
    assert_true(scenario_only.selection.build_prerequisites.contains(root))
  }
  let command = intent_closure_review(tree, graph, {
    ..extra,
    commands: ["cat"],
    backends: ["wasm"],
    evidence: ["backend-pair"],
    observations: ["stderr"],
  })
  assert_eq(command.selection.commands, ["cat"])
  assert_true(command.selection.behaviors.contains(child.behavior_id))
  assert_true(command.selection.behaviors.contains(published.behavior_id))
  assert_true(!command.selection.behaviors.contains(ordinary_sh.behavior_id))
  assert_true(!command.selection.behaviors.contains("wc-ordinary"))
  assert_true(command.selection.published_coordinates.contains("cli/sh@0.2.1"))
  assert_eq(
    command.selection.requirements.filter(row => {
      row.behavior_id == child.behavior_id
    }),
    sel_requirements([child]),
  )
  assert_eq(
    command.selection.requirements.filter(row => {
      row.behavior_id == published.behavior_id
    }),
    sel_requirements([published]),
  )
  assert_true(
    command.selection.requirements.any(row => {
      row.behavior_id == metadata.behavior_id &&
      row.backends == ["native", "wasm"] &&
      row.evidence == ["backend-pair", "contract"] &&
      row.observations.contains("stderr")
    }),
  )
  let mapping : ScopeBoundary = {
    behavior_id: retired.behavior_id,
    replacement_behaviors: [child.behavior_id],
    rejection_tests: [rejection.behavior_id],
    support_record: "docs/compatibility.md",
    adr: "docs/adr/0001-evidence.md",
    current_limit: "old execution is mapped explicitly",
    unlock_condition: "prove current replacement and rejection",
  }
  let mapped = intent_closure_review(
    tree,
    graph,
    { ..extra, behaviors: [retired.behavior_id], },
    boundaries=[mapping],
  )
  assert_eq(
    mapped.selection.behaviors,
    sorted_strings([
      retired.behavior_id,
      child.behavior_id,
      rejection.behavior_id,
    ]),
  )
  assert_true(mapped.selection.build_prerequisites.contains("commands/sh"))
  assert_true(mapped.selection.build_prerequisites.contains("core/process"))
  let no_rules = intent_closure_tree(registry, "{\"schema\":1,\"rules\":[]}")
  let old_roots = sel_final_prerequisites(
    {
      ..scenario_only.selection,
      packages: ["tests/integration"],
      build_prerequisites: [],
    },
    tree,
    no_rules,
    graph,
    { ..graph, edges: [], },
    registry,
    registry,
  )
  for root in ["commands/sh", "commands/wc", "core/process"] {
    assert_true(old_roots.contains(root))
  }
  let old_registry = {
    ..registry,
    entries: registry.entries + [sel_test_entry("old-only", "timeout")],
  }
  let wildcard = associations.replace_all(old="[\"sh\",\"wc\"]", new="[\"*\"]")
  let wildcard_roots = sel_final_prerequisites(
    {
      ..scenario_only.selection,
      packages: ["tests/integration"],
      build_prerequisites: [],
    },
    intent_closure_tree(old_registry, wildcard),
    no_rules,
    graph,
    graph,
    old_registry,
    registry,
  )
  assert_true(wildcard_roots.contains("commands/timeout"))
  assert_true(wildcard_roots.contains("commands/wc"))
  assert_true(!scenario_only.selection.behaviors.contains("old-only"))
  let newer_child = {
    ..child,
    required_backends: ["wasm"],
    platforms: ["linux"],
  }
  let newer_registry = {
    ..registry,
    entries: registry.entries.map(row => {
      if row.behavior_id == child.behavior_id {
        newer_child
      } else {
        row
      }
    }),
  }
  let both = sel_extra_command_associations(
    metadata_only.selection,
    [{ ..extra, commands: ["cat"], }],
    tree,
    intent_closure_tree(newer_registry, associations),
    registry,
    newer_registry,
  )
  assert_eq(
    both.requirements.filter(row => row.behavior_id == child.behavior_id),
    sel_requirements([child, newer_child]),
  )
  let full_rules = associations
    .replace_all(old="\"cat\"", new="\"wc\"")
    .replace_all(old="\"full\":false", new="\"full\":true")
  let full_tree = intent_closure_tree(registry, full_rules)
  let full = intent_closure_review(
    full_tree,
    graph,
    { ..extra, behaviors: [retired.behavior_id], },
    boundaries=[mapping],
  )
  assert_eq(full.automatic.mode, "docs")
  assert_eq(full.selection.mode, "full")
  assert_true(full.selection.behaviors.contains("wc-ordinary"))
  assert_true(
    full.boundaries.any(row => row.behavior_id == ordinary_sh.behavior_id),
  )
  let full_command = intent_closure_review(full_tree, graph, {
    ..extra,
    commands: ["wc"],
    observations: ["stderr"],
  })
  assert_eq(full_command.automatic.mode, "docs")
  assert_eq(full_command.selection.mode, "full")
  assert_eq(
    full_command.selection.requirements.filter(row => {
      row.behavior_id == child.behavior_id
    }),
    sel_requirements([child]),
  )
  let missing = intent_closure_review(no_rules, graph, {
    ..extra,
    commands: ["cat"],
  })
  assert_eq(missing.automatic.mode, "docs")
  assert_eq(missing.selection.mode, "full")
  assert_true(
    missing.selection.reasons.any(reason => {
      reason.contains("missing non-import association: scenario:child")
    }),
  )
  let aggregate = { ..child, command: "all", }
  let aggregate_registry = {
    ..registry,
    entries: registry.entries.map(row => {
      if row.behavior_id == child.behavior_id {
        aggregate
      } else {
        row
      }
    }),
  }
  let missing_aggregate = intent_closure_review(
    intent_closure_tree(aggregate_registry, "{\"schema\":1,\"rules\":[]}"),
    graph,
    { ..extra, behaviors: [aggregate.behavior_id], },
  )
  assert_eq(missing_aggregate.automatic.mode, "docs")
  assert_eq(missing_aggregate.selection.mode, "full")
  assert_true(missing_aggregate.selection.behaviors.contains("wc-ordinary"))
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
  intent_reviewed_closure_regression()
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
