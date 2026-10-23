///|
test "scope CI execution includes old-side and extra published obligations" {
  let entry = ci_scope_test_entry("current", "cat")
  let plain = ci_scope_test_intent([ci_scope_test_requirement(entry)], [])
  assert_false(ci_scope_needs_published(plain))
  let published = {
    ..plain,
    selection: {
      ..plain.selection,
      requirements: [
        {
          ..plain.selection.requirements[0],
          evidence: ["published-differential"],
        },
      ],
    },
  }
  assert_true(ci_scope_needs_published(published))
  assert_true(
    ci_scope_needs_published({
      ..plain,
      selection: { ..plain.selection, mode: "full", },
    }),
  )
}

///|
test "scope CI projects retirement mappings without dropping old intent obligations" {
  let old = ci_scope_test_entry("old", "retired")
  let replacement = ci_scope_test_entry("new", "cat")
  let rejection = ci_scope_test_entry("rejection", "cat")
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
  let intent = ci_scope_test_intent([ci_scope_test_requirement(old)], [mapping])
  let intent = {
    ..intent,
    selection: {
      ..intent.selection,
      commands: ["retired", "cat"],
      case_ids: ["old", "new", "rejection"],
    },
  }
  let projected = ci_scope_impact(intent, registry=Some(registry))
  assert_eq(projected.affected_commands, ["cat"])
  assert_eq(
    projected.affected_behaviors,
    sorted_unique([replacement.behavior_id, rejection.behavior_id]),
  )
  assert_eq(projected.case_ids, ["new", "rejection"])
  assert_eq(intent.selection.requirements[0].command, "retired")
  assert_eq(intent.selection.behaviors, [old.behavior_id])
  assert_true(ci_scope_errors([], projected, registry).is_empty())
}

///|
test "scope CI retirement preserves a custom stable behavior and its old case binding" {
  let old = {
    ..ci_scope_test_entry("old-case", "retired"),
    behavior_id: "stable-retired",
  }
  let replacement = ci_scope_test_entry("new-case", "cat")
  let rejection = ci_scope_test_entry("rejection", "cat")
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
  let intent = ci_scope_test_intent([ci_scope_test_requirement(old)], [mapping])
  let intent = {
    ..intent,
    selection: {
      ..intent.selection,
      case_ids: [old.case_id, replacement.case_id],
    },
  }
  let projected = ci_scope_impact(intent, registry=Some(registry))
  assert_eq(projected.case_ids, [replacement.case_id])
  assert_eq(intent.selection.requirements[0].case_id, "old-case")
}

///|
test "local scoped audit rejects manual declarations that omit automatic consumers" {
  let first = ci_scope_test_entry("first", "cat")
  let second = ci_scope_test_entry("second", "wc")
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [first, second],
  }
  let intent = ci_scope_test_intent(
    [ci_scope_test_requirement(first), ci_scope_test_requirement(second)],
    [],
  )
  let complete = ci_scope_test_declaration([first, second], [])
  assert_true(
    ci_scope_declaration_errors(intent, complete, registry).is_empty(),
  )
  let incomplete = ci_scope_test_declaration([first], [])
  let errors = ci_scope_declaration_errors(intent, incomplete, registry)
  assert_true(errors.any(error => error.contains(second.behavior_id)))
  assert_true(errors.any(error => error.contains("commands: wc")))
}

///|
test "scope shadow receipts bind selection source run platform inventory and full execution" {
  let context = ci_test_context()
  let entry = ci_scope_test_entry("current", "cat")
  let intent = Some(
    ci_scope_test_intent([ci_scope_test_requirement(entry)], []),
  )
  let report : Json = {
    "schema": 1,
    "context": ToJson::to_json(context),
    "platform": "macos",
    "execution_mode": "full",
    "scope_fingerprint": ci_scope_fingerprint(intent),
    "full_behavior_ids": [entry.behavior_id],
    "shadow": intent.unwrap().selection.to_json(),
  }
  assert_true(
    ci_scope_shadow_errors(report, intent, context, "macos", [entry.behavior_id]).is_empty(),
  )
  let mutations : Array[(String, Json)] = [
    ("platform", "windows"),
    ("execution_mode", "scoped"),
    ("scope_fingerprint", Json("b".repeat(64))),
    ("full_behavior_ids", []),
    ("full_behavior_ids", [entry.behavior_id, entry.behavior_id]),
    ("shadow", { "mode": "docs" }),
    ("context", ToJson::to_json({ ..context, head: context.base, })),
    ("context", ToJson::to_json({ ..context, run_id: "43", })),
  ]
  for (key, value) in mutations {
    guard report is Object(original) else {
      fail("fixture report must be an object")
    }
    let changed = original.copy()
    changed[key] = value
    assert_false(
      ci_scope_shadow_errors(Json::object(changed), intent, context, "macos", [
        entry.behavior_id,
      ]).is_empty(),
    )
  }
}

///|
test "scope supplementary execution never proves semantic parity or rejection" {
  let metadata = audit_metadata("diagnostic")
  let entry = {
    ..audit_entry(),
    required_backends: ["native"],
    required_evidence: ["supplementary"],
  }
  let row = audit_row("diagnostic", "native", "supplementary")
  assert_true(
    row_proves(
      row,
      metadata,
      entry,
      "supplementary",
      "native",
      entry.observations,
    ),
  )
  for
    evidence in [
      "contract", "backend-pair", "upstream-differential", "published-differential",
      "boundary",
    ] {
    assert_false(
      row_proves(row, metadata, entry, evidence, "native", entry.observations),
    )
  }
}

///|
test "unresolvable main before selects full regression while PR context stays exact" {
  let supplied = ci_test_context()
  let fallback = {
    ..supplied,
    event: "push",
    base: "",
    unresolved_base: Some("0".repeat(40)),
  }
  assert_true(ci_context_errors(fallback, []).is_empty())
  assert_false(
    ci_context_errors({ ..fallback, event: "pull_request", }, [
      supplied.base,
      supplied.pr_head,
    ]).is_empty(),
  )
  assert_false(
    ci_context_errors({ ..fallback, base: supplied.base, }, []).is_empty(),
  )
  assert_false(
    ci_context_errors({ ..fallback, unresolved_base: Some("unknown-ref"), }, []).is_empty(),
  )
  assert_false(
    ci_receipt_context_errors(fallback, {
      ..fallback,
      unresolved_base: Some("d".repeat(40)),
    }).is_empty(),
  )
}

///|
test "full current execution cannot be replaced by a shadow retirement mapping or empty summaries" {
  let current = ci_scope_test_entry("current", "cat")
  let replacement = ci_scope_test_entry("replacement", "cat")
  let rejection = ci_scope_test_entry("rejection", "cat")
  let entries = [current, replacement, rejection]
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries,
  }
  let full = ci_scope_test_intent(entries.map(ci_scope_test_requirement), [])
  let old = { ..ci_scope_test_requirement(current), case_id: "old-case", }
  let mapping = ci_scope_test_mapping(
    current.behavior_id,
    [replacement.behavior_id],
    rejection.behavior_id,
  )
  let shadow = ci_scope_test_intent([old], [mapping])
  let impact = ci_full_shadow_impact(full, Some(shadow), registry)
  assert_true(impact.affected_behaviors.contains(current.behavior_id))
  let complete = ci_scope_test_bundle(
    "full", "macos", "native", "contract", entries,
  )
  let declaration = ci_scope_test_declaration(entries, [complete])
  assert_true(
    validate_scope_requirements(full, declaration, registry, [complete], [
      "macos",
    ]).is_empty(),
  )
  let missing_current = {
    ..complete,
    rows: complete.rows.filter(row => row.id != current.case_id),
  }
  assert_true(
    validate_scope_requirements(
      shadow,
      declaration,
      registry,
      [missing_current],
      ["macos"],
    ).is_empty(),
  )
  assert_false(
    validate_scope_requirements(
      full,
      declaration,
      registry,
      [missing_current],
      ["macos"],
    ).is_empty(),
  )
  assert_false(
    validate_scope_requirements(
      full,
      declaration,
      registry,
      [{ ..complete, rows: [], }],
      ["macos"],
    ).is_empty(),
  )
  assert_false(
    ci_scope_shadow_errors({}, None, ci_test_context(), "macos", []).is_empty(),
  )
}
