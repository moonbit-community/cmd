///|
priv struct CiHarnessBinding {
  path : String
  behavior_ids : Array[String]
} derive(FromJson)

///|
// This input describes impact and requirements, never observed outcomes.
priv struct CiImpact {
  schema : Int32
  affected_commands : Array[String]
  affected_behaviors : Array[String]
  affected_options : Array[String]
  affected_operands : Array[String]
  case_ids : Array[String]
  core_impact : String?
  published_manifest_affected : Bool
  required_backends : Array[String]
  required_evidence : Array[String]
  required_observations : Array[String]
  boundaries : Array[BoundaryRecord]
  deferred : Array[String]
  uncovered : Array[String]
  harness_bindings : Array[CiHarnessBinding]
} derive(FromJson)

///|
fn ci_impact(value : Json) -> CiImpact raise {
  if value is { "schema": Number(2, ..), .. } {
    return ci_scope_impact(@scope.parse_intent(value))
  }
  guard value is Object(fields) else { fail("CI impact must be an object") }
  let allowed = [
    "schema", "affected_commands", "affected_behaviors", "affected_options", "affected_operands",
    "case_ids", "core_impact", "published_manifest_affected", "required_backends",
    "required_evidence", "required_observations", "boundaries", "deferred", "uncovered",
    "harness_bindings",
  ]
  for key in fields.keys() {
    guard allowed.contains(key) else {
      fail("CI impact contains an unknown field or execution claim: " + key)
    }
  }
  let impact : CiImpact = @json.from_json(value)
  guard impact.schema == 1 else { fail("CI impact requires schema 1") }
  impact
}

///|
fn ci_scope_impact(
  intent : @scope.ScopeIntent,
  registry~ : @registry.Registry? = None,
) -> CiImpact {
  let selected = intent.selection
  let projected : Array[String] = []
  for id in selected.behaviors {
    let mappings = intent.boundaries.filter(row => row.behavior_id == id)
    if mappings.any(row => !row.replacement_behaviors.is_empty()) {
      projected.append(ci_scope_mapped_targets(intent, id))
    } else {
      projected.push(id)
      projected.append(ci_scope_mapped_targets(intent, id))
    }
  }
  let commands = selected.commands.filter(command => {
    guard registry is Some(registry) else { return true }
    if registry.entries.any(entry => entry.command == command) {
      return true
    }
    let old = selected.requirements.filter(row => row.command == command)
    old.is_empty() ||
    !old.all(row => {
      intent.boundaries.any(mapping => {
        mapping.behavior_id == row.behavior_id &&
        !mapping.replacement_behaviors.is_empty()
      })
    })
  })
  {
    schema: 2,
    affected_commands: commands,
    affected_behaviors: sorted_unique(projected),
    affected_options: selected.affected_options,
    affected_operands: selected.affected_operands,
    case_ids: selected.case_ids.filter(id => {
      guard registry is Some(registry) else { return true }
      registry.entries.any(entry => entry.case_id == id) ||
      !selected.requirements.any(requirement => {
        requirement.case_id == id &&
        intent.boundaries.any(mapping => {
          mapping.behavior_id == requirement.behavior_id &&
          !mapping.replacement_behaviors.is_empty()
        })
      })
    }),
    core_impact: if selected.core_packages.is_empty() {
      None
    } else {
      Some("all")
    },
    published_manifest_affected: intent.changes.any(change => {
      [change.old_path, change.new_path].any(path => {
        path.has_prefix("tests/release_runner/current/published") ||
        path.has_prefix("tests/release_runner/historical/published-")
      })
    }),
    required_backends: [],
    required_evidence: [],
    required_observations: [],
    boundaries: intent.boundaries
    .filter(row => row.replacement_behaviors.is_empty())
    .map(boundary => {
      behavior_id: boundary.behavior_id,
      support_record: boundary.support_record,
      adr: boundary.adr,
      current_limit: boundary.current_limit,
      unlock_condition: boundary.unlock_condition,
    }),
    deferred: intent.deferred,
    uncovered: intent.uncovered,
    harness_bindings: [],
  }
}

///|
fn ci_documentation_path(path : String) -> Bool {
  // Current support records, ADRs, agent rules and executable docs stay gated.
  path.has_prefix("docs/reports/") &&
  !path.has_suffix(".mbt.md") &&
  path.has_suffix(".md")
}

///|
fn ci_scope_errors(
  paths : ArrayView[String],
  impact : CiImpact,
  registry : @registry.Registry,
) -> Array[String] {
  let failures : Array[String] = []
  // Schema-v2 freshness and closure are recomputed before execution and audit.
  // Requiring the declaration filename to change would reject a same-tree
  // re-push while accepting an unrelated timestamp edit under schema 1.
  if impact.schema == 2 {
    for id in impact.affected_behaviors {
      if find_entry(registry, id) is None {
        failures.push(
          "removed behavior requires explicit replacement evidence: " + id,
        )
      }
    }
    return failures
  }
  if !paths.contains("tests/coverage/ci-change.json") {
    failures.push("CI impact must be updated within the audited change range")
  }
  let affected = canonical_ids(registry, impact.affected_behaviors)
  let bound : Map[String, Bool] = Map([])
  for binding in impact.harness_bindings {
    if bound.contains(binding.path) ||
      !paths.contains(binding.path) ||
      binding.behavior_ids.is_empty() {
      failures.push(
        "invalid, stale or duplicate harness binding: " + binding.path,
      )
    }
    bound[binding.path] = true
    for id in binding.behavior_ids {
      match find_entry(registry, id) {
        Some(entry) if affected.contains(entry.behavior_id) &&
          entry.implementation == "package-test" &&
          entry.source.has_prefix("tests/") => ()
        _ =>
          failures.push(
            "harness binding requires an affected registered harness test: " +
            id,
          )
      }
    }
  }
  for path in paths {
    if ci_documentation_path(path) ||
      path == "tests/coverage/ci-change.json" ||
      path.has_prefix("commands/") ||
      path.has_prefix("core/") {
      continue
    }
    let owned = registry.entries.any(entry => {
      entry.source
      .split("::")
      .next()
      .map(source => source == path)
      .unwrap_or(false)
    })
    let frozen = path.has_suffix(".json") &&
      (
        path.has_prefix("tests/release_runner/historical/published-") ||
        path.has_prefix("tests/release_runner/current/published")
      )
    if frozen {
      if !impact.published_manifest_affected {
        failures.push(
          "frozen release record changes require published_manifest_affected: " +
          path,
        )
      }
    } else if !owned && !bound.contains(path) {
      failures.push(
        "changed harness/configuration path requires a reviewed harness binding: " +
        path,
      )
    }
  }
  failures
}

///|
fn ci_local_harness_scope_errors(
  paths : ArrayView[String],
  declaration : ChangeDeclaration,
  impact : CiImpact,
  registry : @registry.Registry,
) -> Array[String] {
  let failures = ci_scope_errors(paths, impact, registry)
  if !impact.affected_commands.is_empty() {
    failures.push(
      "scope: reviewed harness-only impact must have no affected commands",
    )
  }
  if declaration.core_impact is Some(_) || impact.core_impact is Some(_) {
    failures.push("scope: harness-only coverage cannot declare core impact")
  }
  if !declaration.boundaries.is_empty() ||
    !declaration.deferred.is_empty() ||
    !declaration.uncovered.unwrap_or([]).is_empty() ||
    !impact.boundaries.is_empty() ||
    !impact.deferred.is_empty() ||
    !impact.uncovered.is_empty() {
    failures.push(
      "scope: harness-only coverage requires passing package tests without boundaries, deferrals or uncovered behaviors",
    )
  }
  if canonical_ids(registry, declaration.affected_behaviors) !=
    canonical_ids(registry, impact.affected_behaviors) {
    failures.push(
      "scope: local harness behaviors differ from reviewed CI impact",
    )
  }
  if declaration.published_manifest_affected !=
    Some(impact.published_manifest_affected) {
    failures.push(
      "scope: local published manifest impact differs from reviewed CI impact",
    )
  }
  for
    (name, supplied, reviewed) in [
      (
        "required_backends",
        declaration.required_backends,
        impact.required_backends,
      ),
      (
        "required_evidence",
        declaration.required_evidence,
        impact.required_evidence,
      ),
      (
        "required_observations",
        declaration.required_observations,
        impact.required_observations,
      ),
      (
        "affected_options",
        declaration.affected_options.unwrap_or([]),
        impact.affected_options,
      ),
      (
        "affected_operands",
        declaration.affected_operands.unwrap_or([]),
        impact.affected_operands,
      ),
      ("case_ids", declaration.case_ids.unwrap_or([]), impact.case_ids),
    ] {
    if sorted_unique(supplied.copy()) != sorted_unique(reviewed.copy()) {
      failures.push("scope: local " + name + " differs from reviewed CI impact")
    }
  }
  failures
}

///|
fn ci_declaration(
  impact : CiImpact,
  registry : @registry.Registry,
  report_paths : Array[String],
) -> ChangeDeclaration raise {
  let records : Array[CoverageRecord] = []
  let seen : Set[String] = Set([])
  for id in impact.affected_behaviors {
    guard find_entry(registry, id) is Some(entry) else {
      fail("CI impact names an unknown behavior: " + id)
    }
    guard !seen.contains(entry.behavior_id) else {
      fail("CI impact repeats a canonical behavior: " + id)
    }
    seen.add(entry.behavior_id)
    let boundary = impact.deferred.any(id => {
        find_entry(registry, id) is Some(deferred) &&
        deferred.behavior_id == entry.behavior_id
      }) &&
      entry.status == "boundary"
    records.push({
      behavior_id: entry.behavior_id,
      backends: sorted_unique(
        entry.required_backends + impact.required_backends,
      ),
      evidence: if boundary {
        ["boundary"]
      } else {
        sorted_unique(entry.required_evidence + impact.required_evidence)
      },
      observations: sorted_unique(
        entry.observations + impact.required_observations,
      ),
      // An obligation is not a supplied result. Only evidence rows can pass it.
      result: "required",
      report: None,
      reports: Some(report_paths),
    })
  }
  {
    schema: 1,
    affected_commands: impact.affected_commands,
    affected_behaviors: impact.affected_behaviors,
    affected_options: Some(impact.affected_options),
    affected_operands: Some(impact.affected_operands),
    case_ids: Some(impact.case_ids),
    core_impact: impact.core_impact,
    published_manifest_affected: Some(impact.published_manifest_affected),
    required_backends: impact.required_backends,
    required_evidence: impact.required_evidence,
    required_observations: impact.required_observations,
    coverage: records,
    boundaries: impact.boundaries,
    deferred: impact.deferred,
    uncovered: Some(impact.uncovered),
  }
}
