///|
fn ci_scope_test_entry(
  id : String,
  command : String,
) -> @registry.RegistryEntry {
  {
    ..audit_entry(),
    behavior_id: "case:" + id,
    command,
    owner: "commands/" + command,
    case_id: id,
    aliases: [],
    source: "tests/cases/" + id + ".json",
    required_backends: ["native"],
    required_evidence: ["contract"],
    platforms: ["macos"],
  }
}

///|
fn ci_scope_test_requirement(
  entry : @registry.RegistryEntry,
) -> @scope.BehaviorRequirement {
  {
    behavior_id: entry.behavior_id,
    case_id: entry.case_id,
    command: entry.command,
    backends: entry.required_backends,
    evidence: entry.required_evidence,
    observations: entry.observations,
    platforms: entry.platforms,
    oracle_profile: entry.oracle_profile,
  }
}

///|
fn ci_scope_test_mapping(
  old_id : String,
  replacements : Array[String],
  rejection : String,
) -> @scope.ScopeBoundary {
  {
    behavior_id: old_id,
    replacement_behaviors: replacements,
    rejection_tests: [rejection],
    support_record: "docs/compatibility.md",
    adr: "docs/adr/0001-evidence.md",
    current_limit: "old owner is retired",
    unlock_condition: "the replacement and rejection obligations pass",
  }
}

///|
fn ci_scope_test_intent(
  requirements : Array[@scope.BehaviorRequirement],
  boundaries : Array[@scope.ScopeBoundary],
) -> @scope.ScopeIntent {
  let hash = "a".repeat(64)
  let selection : @scope.Selection = {
    mode: "scoped",
    reasons: [],
    changed_paths: [],
    commands: sorted_unique(requirements.map(row => row.command)),
    behaviors: sorted_unique(requirements.map(row => row.behavior_id)),
    packages: [],
    core_packages: [],
    build_prerequisites: [],
    case_ids: [],
    published_coordinates: [],
    affected_options: [],
    affected_operands: [],
    requirements,
  }
  {
    schema: 2,
    transition: "shadow-full",
    policy_version: "scope-v2.1",
    target_ref: "origin/main",
    base: "b".repeat(40),
    payload: hash,
    change_set: hash,
    changes: [],
    identities: {
      base_policy: hash,
      candidate_policy: hash,
      base_graph: hash,
      candidate_graph: hash,
      base_registry: hash,
      candidate_registry: hash,
      base_associations: hash,
      candidate_associations: hash,
    },
    automatic: selection,
    extras: [],
    selection,
    boundaries,
    deferred: [],
    uncovered: [],
  }
}

///|
fn ci_scope_test_bundle(
  id : String,
  platform : String,
  backend : String,
  verification : String,
  entries : Array[@registry.RegistryEntry],
  profile~ : String = "",
  oracle_checked~ : Bool = true,
) -> EvidenceBundle {
  let metadata = {
    ..audit_metadata(id),
    platform,
    oracle_profile_id: profile,
    oracle_image_digest: if profile == "" {
      ""
    } else {
      "sha256:" + "c".repeat(64)
    },
    oracle_versions_hash: if profile == "" {
      ""
    } else {
      "d".repeat(64)
    },
  }
  {
    report_path: @path.Path("reports/" + id + "/summary.jsonl")
    .normalize()
    .to_string(),
    metadata,
    rows: entries.map(entry => {
      ..audit_row(id, backend, verification),
      id: entry.case_id,
      platform,
      oracle_profile_id: profile,
    }),
    selected_ids: entries.map(entry => entry.case_id),
    oracle_verified: oracle_checked,
    published_coordinates: [],
  }
}

///|
fn ci_scope_test_declaration(
  entries : Array[@registry.RegistryEntry],
  bundles : Array[EvidenceBundle],
) -> ChangeDeclaration {
  {
    ..declaration_for_test("unused", "required"),
    affected_commands: sorted_unique(entries.map(entry => entry.command)),
    affected_behaviors: entries.map(entry => entry.behavior_id),
    required_backends: [],
    required_evidence: [],
    required_observations: [],
    coverage: entries.map(entry => {
      behavior_id: entry.behavior_id,
      backends: entry.required_backends,
      evidence: entry.required_evidence,
      observations: entry.observations,
      result: "required",
      report: None,
      reports: Some(bundles.map(bundle => bundle.report_path)),
    }),
  }
}

///|
test "scope CI cannot borrow a moved command owner without an explicit replacement" {
  let old = ci_scope_test_entry("stable", "old-owner")
  let moved = { ..old, command: "new-owner", owner: "commands/new-owner", }
  let rejection = ci_scope_test_entry("rejection", "new-owner")
  let entries = [moved, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let bundles = [
    ci_scope_test_bundle("moved", "macos", "native", "contract", entries),
  ]
  let declaration = ci_scope_test_declaration(entries, bundles)
  let requirement = ci_scope_test_requirement(old)
  let unmapped = ci_scope_test_intent([requirement], [])
  assert_true(
    validate_scope_requirements(unmapped, declaration, registry, bundles, [
      "macos",
    ]).any(problem => problem.contains("moved command")),
  )
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [moved.behavior_id],
    rejection.behavior_id,
  )
  let mapped = ci_scope_test_intent([requirement], [mapping])
  assert_eq(
    validate_scope_requirements(mapped, declaration, registry, bundles, [
      "macos",
    ]),
    [],
  )
  assert_eq(
    ci_scope_mapped_targets(mapped, old.behavior_id),
    sorted_unique([rejection.behavior_id, moved.behavior_id]),
  )
}

///|
test "scope CI stable behavior IDs cannot substitute a new case binding without review" {
  let old = { ..ci_scope_test_entry("stable", "echo"), case_id: "old-case", }
  let renamed = {
    ..old,
    case_id: "new-case",
    required_backends: ["native", "wasm"],
    required_evidence: ["contract", "backend-pair"],
  }
  let rejection = ci_scope_test_entry("rejection", "echo")
  let entries = [renamed, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let current = ci_scope_test_bundle(
    "renamed", "macos", "native+wasm", "backend-pair", entries,
  )
  let declaration = ci_scope_test_declaration(entries, [current])
  let requirement = ci_scope_test_requirement(old)
  let unmapped = ci_scope_test_intent([requirement], [])
  assert_true(
    validate_scope_requirements(unmapped, declaration, registry, [current], [
      "macos",
    ]).any(problem => problem.contains("moved case binding")),
  )
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [renamed.behavior_id],
    rejection.behavior_id,
  )
  let mapped = ci_scope_test_intent([requirement], [mapping])
  assert_eq(
    validate_scope_requirements(mapped, declaration, registry, [current], [
      "macos",
    ]),
    [],
  )
  let only_old_strength = ci_scope_test_bundle(
    "native-only", "macos", "native", "contract", entries,
  )
  let weak_declaration = ci_scope_test_declaration(entries, [only_old_strength])
  assert_true(
    validate_scope_requirements(
      mapped,
      weak_declaration,
      registry,
      [only_old_strength],
      ["macos"],
    ).any(problem => {
      problem.contains("mapped current obligation") &&
      problem.contains("backend-pair")
    }),
  )
}

///|
test "scope CI accepts canonical coverage aliases and rejects duplicate canonical records" {
  let entry = {
    ..ci_scope_test_entry("current", "echo"),
    aliases: ["legacy-current"],
  }
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry],
  }
  let intent = ci_scope_test_intent([ci_scope_test_requirement(entry)], [])
  let bundles = [
    ci_scope_test_bundle("alias", "macos", "native", "contract", [entry]),
  ]
  let declaration = ci_scope_test_declaration([entry], bundles)
  let canonical = declaration.coverage[0]
  assert_eq(
    report_references(canonical),
    bundles.map(bundle => bundle.report_path),
  )
  let noncanonical = {
    ..bundles[0],
    report_path: "reports/./alias/summary.jsonl",
  }
  let noncanonical_declaration = ci_scope_test_declaration([entry], [
    noncanonical,
  ])
  assert_true(
    validate_scope_requirements(
      intent,
      noncanonical_declaration,
      registry,
      [noncanonical],
      ["macos"],
    ).any(problem => problem.contains("report has no supplied run metadata")),
  )
  for id in ["legacy-current", entry.case_id] {
    let aliased_row = { ..canonical, behavior_id: id, }
    let aliased = {
      ..declaration,
      affected_behaviors: [id],
      coverage: [aliased_row],
    }
    assert_eq(
      validate_scope_requirements(intent, aliased, registry, bundles, ["macos"]),
      [],
    )
    let duplicate = { ..declaration, coverage: [canonical, aliased_row], }
    assert_true(
      validate_scope_requirements(intent, duplicate, registry, bundles, [
        "macos",
      ]).any(problem => problem.contains("exactly one coverage record")),
    )
  }
}

///|
test "scope CI requires every replacement and rejection execution plus coverage references" {
  let old = ci_scope_test_entry("removed", "retired")
  let first = ci_scope_test_entry("first", "new")
  let second = ci_scope_test_entry("second", "new")
  let rejection = ci_scope_test_entry("rejection", "new")
  let entries = [first, second, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [first.behavior_id, second.behavior_id],
    rejection.behavior_id,
  )
  let intent = ci_scope_test_intent([ci_scope_test_requirement(old)], [mapping])
  let complete = ci_scope_test_bundle(
    "all", "macos", "native", "contract", entries,
  )
  let declaration = ci_scope_test_declaration(entries, [complete])
  assert_eq(
    validate_scope_requirements(intent, declaration, registry, [complete], [
      "macos",
    ]),
    [],
  )
  for absent in entries {
    let missing = {
      ..complete,
      rows: complete.rows.filter(row => row.id != absent.case_id),
    }
    assert_false(
      validate_scope_requirements(intent, declaration, registry, [missing], [
        "macos",
      ]).is_empty(),
    )
  }
  assert_false(
    validate_scope_requirements(
      intent,
      { ..declaration, coverage: [], },
      registry,
      [complete],
      ["macos"],
    ).is_empty(),
  )
  let failed = {
    ..complete,
    rows: complete.rows.map(row => {
      if row.id == rejection.case_id {
        { ..row, result: "fail", }
      } else {
        row
      }
    }),
  }
  assert_false(
    validate_scope_requirements(intent, declaration, registry, [failed], [
      "macos",
    ]).is_empty(),
  )
  let unobserved = {
    ..complete,
    rows: complete.rows.map(row => {
      if row.id == rejection.case_id {
        { ..row, observations: ["status"], missing_observations: ["stdout"], }
      } else {
        row
      }
    }),
  }
  assert_false(
    validate_scope_requirements(intent, declaration, registry, [unobserved], [
      "macos",
    ]).is_empty(),
  )
}

///|
test "scope CI rejects stale ambiguous and alias replacement mappings" {
  let old = ci_scope_test_entry("removed", "retired")
  let replacement = {
    ..ci_scope_test_entry("current", "new"),
    aliases: ["legacy-current"],
  }
  let rejection = ci_scope_test_entry("rejection", "new")
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [replacement, rejection],
  }
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [replacement.behavior_id],
    rejection.behavior_id,
  )
  let requirement = ci_scope_test_requirement(old)
  let replacement_only = { ..mapping, rejection_tests: [], }
  assert_eq(
    ci_scope_mapping_errors(
      ci_scope_test_intent([requirement], [replacement_only]),
      registry,
    ),
    [],
  )
  assert_false(
    ci_scope_mapping_errors(
      ci_scope_test_intent([requirement], [replacement_only]),
      {
        ..registry,
        entries: registry.entries + [{ ..old, status: "boundary", }],
      },
    ).is_empty(),
  )
  for
    boundaries in [
      [mapping, mapping],
      [{ ..mapping, behavior_id: "case:unknown-old", }],
      [{ ..mapping, replacement_behaviors: [], }],
      [{ ..mapping, replacement_behaviors: ["legacy-current"], }],
      [
        {
          ..mapping,
          replacement_behaviors: [
            replacement.behavior_id,
            replacement.behavior_id,
          ],
        },
      ],
      [{ ..mapping, rejection_tests: ["case:unknown-rejection"], }],
      [{ ..mapping, rejection_tests: [], replacement_behaviors: [], }],
    ] {
    assert_false(
      ci_scope_mapping_errors(
        ci_scope_test_intent([requirement], boundaries),
        registry,
      ).is_empty(),
    )
  }
}

///|
test "scope CI keeps old Native Windows and current Wasm Linux obligations separate" {
  let old = {
    ..ci_scope_test_entry("retired", "old"),
    status: "boundary",
    required_evidence: ["boundary"],
    platforms: ["windows"],
  }
  let replacement = {
    ..ci_scope_test_entry("new", "new"),
    required_backends: ["wasm"],
    platforms: ["linux"],
  }
  let rejection = {
    ..ci_scope_test_entry("rejection", "new"),
    platforms: ["windows"],
  }
  let entries = [replacement, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [replacement.behavior_id],
    rejection.behavior_id,
  )
  let intent = ci_scope_test_intent([ci_scope_test_requirement(old)], [mapping])
  let old_execution = ci_scope_test_bundle(
    "old-windows",
    "windows",
    "native",
    "contract",
    [replacement],
  )
  let current_execution = ci_scope_test_bundle(
    "current-linux",
    "linux",
    "wasm",
    "contract",
    [replacement],
  )
  let rejected = ci_scope_test_bundle(
    "rejected-windows",
    "windows",
    "native",
    "contract",
    [rejection],
  )
  let bundles = [old_execution, current_execution, rejected]
  let declaration = ci_scope_test_declaration(entries, bundles)
  let hosts = ["linux", "windows"]
  assert_eq(
    validate_scope_requirements(intent, declaration, registry, bundles, hosts),
    [],
  )
  assert_false(
    validate_scope_requirements(
      intent,
      declaration,
      { ..registry, entries: entries + [old], },
      bundles,
      hosts,
    ).is_empty(),
  )
  for incomplete in [[old_execution, rejected], [current_execution, rejected]] {
    let declared = ci_scope_test_declaration(entries, incomplete)
    assert_false(
      validate_scope_requirements(intent, declared, registry, incomplete, hosts).is_empty(),
    )
  }
  let wrong_platform = ci_scope_test_bundle(
    "wrong-linux",
    "linux",
    "native",
    "contract",
    [replacement],
  )
  let wrong_backend = ci_scope_test_bundle(
    "wrong-wasm",
    "windows",
    "wasm",
    "contract",
    [replacement],
  )
  for wrong in [wrong_platform, wrong_backend] {
    let selected = [wrong, current_execution, rejected]
    let declared = ci_scope_test_declaration(entries, selected)
    assert_false(
      validate_scope_requirements(intent, declared, registry, selected, hosts).is_empty(),
    )
  }
  let unobserved = {
    ..old_execution,
    rows: old_execution.rows.map(row => {
      ..row,
      observations: ["status"],
      missing_observations: ["stdout"],
    }),
  }
  let selected = [unobserved, current_execution, rejected]
  assert_false(
    validate_scope_requirements(
      intent,
      ci_scope_test_declaration(entries, selected),
      registry,
      selected,
      hosts,
    ).is_empty(),
  )
}

///|
test "scope CI replacement preserves old oracle profile and sealed differential evidence" {
  let old = {
    ..ci_scope_test_entry("retired", "old"),
    required_evidence: ["upstream-differential"],
    platforms: ["linux"],
    oracle_profile: "old-oracle",
  }
  let replacement = {
    ..old,
    behavior_id: "case:new",
    case_id: "new",
    aliases: [],
    command: "new",
    owner: "commands/new",
    oracle_profile: "new-oracle",
  }
  let rejection = {
    ..ci_scope_test_entry("rejection", "new"),
    platforms: ["linux"],
  }
  let entries = [replacement, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [replacement.behavior_id],
    rejection.behavior_id,
  )
  let intent = ci_scope_test_intent([ci_scope_test_requirement(old)], [mapping])
  let prior = ci_scope_test_bundle(
    "old-profile",
    "linux",
    "native",
    "differential",
    [replacement],
    profile="old-oracle",
  )
  let current = ci_scope_test_bundle(
    "new-profile",
    "linux",
    "native",
    "differential",
    [replacement],
    profile="new-oracle",
  )
  let rejected = ci_scope_test_bundle(
    "rejected",
    "linux",
    "native",
    "contract",
    [rejection],
  )
  let bundles = [prior, current, rejected]
  let declaration = ci_scope_test_declaration(entries, bundles)
  assert_eq(
    validate_scope_requirements(intent, declaration, registry, bundles, [
      "linux",
    ]),
    [],
  )
  let substituted = [current, rejected]
  assert_false(
    validate_scope_requirements(
      intent,
      ci_scope_test_declaration(entries, substituted),
      registry,
      substituted,
      ["linux"],
    ).is_empty(),
  )
  let unsealed = [{ ..prior, oracle_verified: false, }, current, rejected]
  assert_false(
    validate_scope_requirements(intent, declaration, registry, unsealed, [
      "linux",
    ]).is_empty(),
  )
}

///|
test "scope CI mapped retirement crosses the changed-command gate only for old deleted paths" {
  let old = ci_scope_test_entry("removed", "retired")
  let replacement = ci_scope_test_entry("new", "echo")
  let rejection = ci_scope_test_entry("rejection", "echo")
  let entries = [replacement, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let mapping = ci_scope_test_mapping(
    old.behavior_id,
    [replacement.behavior_id],
    rejection.behavior_id,
  )
  let deleted : @scope.GitChange = {
    status: "D",
    old_path: "commands/retired/main.mbt",
    new_path: "",
    old_mode: "100644",
    new_mode: "000000",
    old_blob: "a".repeat(40),
    new_blob: "0".repeat(40),
  }
  let intent = {
    ..ci_scope_test_intent(
      [
        ci_scope_test_requirement(old),
        ci_scope_test_requirement(replacement),
        ci_scope_test_requirement(rejection),
      ],
      [mapping],
    ),
    changes: [deleted],
  }
  let retired = ci_scope_retired_commands(intent, registry)
  assert_eq(retired, ["retired"])
  let impact = ci_scope_impact(intent, registry=Some(registry))
  let declaration = ci_declaration(impact, registry, [
    "reports/current/summary.jsonl",
  ])
  let paths = [deleted.old_path]
  let (_, _, before) = validate_changed_scope(paths, declaration, registry)
  assert_true(
    before.any(problem => problem.contains("missing from affected_commands")),
  )
  let (actual, _, after) = validate_changed_scope(
    paths,
    declaration,
    registry,
    retired~,
  )
  assert_eq(actual, ["retired"])
  assert_true(after.is_empty())
  let (_, _, active) = validate_changed_scope(
    ["commands/echo/main.mbt"],
    declaration,
    registry,
    retired=["echo"],
  )
  assert_true(
    active.any(problem => {
      problem.contains("current command cannot be treated as retired")
    }),
  )
  let edited = {
    ..deleted,
    status: "M",
    new_path: deleted.old_path,
    new_mode: "100644",
    new_blob: "b".repeat(40),
  }
  assert_eq(
    ci_scope_retired_commands({ ..intent, changes: [edited], }, registry),
    [],
  )
  let unmapped = { ..intent, boundaries: [], }
  assert_eq(ci_scope_retired_commands(unmapped, registry), [])
}
