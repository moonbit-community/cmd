///|
async fn ci_scope_preflight(context : CiContext) -> @scope.ScopeIntent? {
  if context.base == "" {
    if context.unresolved_base is Some(_) {
      // Full execution cannot repair a malformed current declaration. Its
      // stale PR range is not used to filter an unresolvable main push.
      ignore(
        @scope.parse_intent_text(
          @fs.read_file("tests/coverage/ci-change.json").text(),
        ),
      )
    }
    return None
  }
  let errors = ci_report_history_errors(context.base, context.head)
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let root = ci_git(["rev-parse", "--show-toplevel"])
  Some(
    @scope.verify_checkout_intent(
      root,
      context.base,
      context.head,
      if context.event == "workflow_dispatch" {
        "push"
      } else {
        context.event
      },
    ),
  )
}

///|
fn ci_scope_fingerprint(intent : @scope.ScopeIntent?) -> String {
  match intent {
    Some(intent) => @testkit.json_digest(intent.to_json())
    None => @testkit.json_digest({ "mode": "regression-only/full" })
  }
}

///|
async fn ci_write_scope_shadow(
  context : CiContext,
  directory : String,
  intent : @scope.ScopeIntent?,
) -> Unit {
  let registry = @registry.load("tests/registry/registry.json")
  let report : Json = {
    "schema": 1,
    "context": ToJson::to_json(context),
    "platform": @testkit.host_platform(),
    "execution_mode": "full",
    "scope_fingerprint": ci_scope_fingerprint(intent),
    "full_behavior_ids": @registry.behavior_ids(registry),
    "shadow": match intent {
      Some(intent) => intent.selection.to_json()
      None => { "mode": "regression-only/full" }
    },
  }
  @fs.write_file(
    directory + "/scope-shadow.json",
    @testkit.canonical_json(report) + "\n",
    create_mode=CreateNew,
  )
}

///|
async fn ci_verify_scope_shadow(
  context : CiContext,
  directory : String,
  platform : String,
  intent : @scope.ScopeIntent?,
) -> Unit {
  let report = @scope.strict_json(
    @fs.read_file(directory + "/scope-shadow.json").text(),
  )
  let registry = @registry.load("tests/registry/registry.json")
  let errors = ci_scope_shadow_errors(
    report,
    intent,
    context,
    platform,
    @registry.behavior_ids(registry),
  )
  guard errors.is_empty() else { fail(errors.join("\n")) }
}

///|
fn ci_scope_shadow_errors(
  report : Json,
  intent : @scope.ScopeIntent?,
  context : CiContext,
  platform : String,
  expected_ids : Array[String],
) -> Array[String] {
  guard !expected_ids.is_empty() else {
    return ["full regression requires a nonempty current behavior inventory"]
  }
  guard report
    is {
      "schema": Number(1, ..),
      "context": saved_context,
      "platform": String(saved_platform),
      "execution_mode": String("full"),
      "scope_fingerprint": String(fingerprint),
      "full_behavior_ids": ids,
      "shadow": shadow,
      ..
    } else {
    return ["missing or malformed full/shadow execution responsibility"]
  }
  guard report is Object(fields) && fields.length() == 7 else {
    return ["unexpected scope-shadow receipt fields"]
  }
  let saved : CiContext = @json.from_json(saved_context) catch {
    _ => return ["invalid shadow workflow context"]
  }
  let errors = ci_receipt_context_errors(saved, context)
  if saved_platform != platform || fingerprint != ci_scope_fingerprint(intent) {
    errors.push(
      "scope shadow belongs to another source, range, platform or workflow",
    )
  }
  let expected_shadow = match intent {
    Some(intent) => intent.selection.to_json()
    None => { "mode": "regression-only/full" }
  }
  if shadow != expected_shadow {
    errors.push(
      "recorded shadow differs from the verified actual-range selection",
    )
  }
  let full_ids : Array[String] = @json.from_json(ids) catch {
    _ => return ["invalid full behavior inventory"]
  }
  if sorted_unique(full_ids.copy()) != sorted_unique(expected_ids.copy()) ||
    full_ids.length() != sorted_unique(full_ids.copy()).length() {
    errors.push(
      "shadow comparison does not cover the complete current behavior inventory",
    )
  }
  errors
}

///|
fn ci_scope_current_entry(
  registry : @registry.Registry,
  id : String,
) -> @registry.RegistryEntry? {
  let entries = registry.entries.filter(entry => entry.behavior_id == id)
  if entries is [entry] {
    Some(entry)
  } else {
    None
  }
}

///|
/// Projection is separate from proof: these IDs must still satisfy both the
/// old obligation and each target's own current requirements below.
fn ci_scope_mapped_targets(
  intent : @scope.ScopeIntent,
  behavior_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for boundary in intent.boundaries {
    if boundary.behavior_id == behavior_id {
      ids.append(boundary.replacement_behaviors)
      ids.append(boundary.rejection_tests)
    }
  }
  sorted_unique(ids)
}

///|
fn ci_scope_mapping_errors(
  intent : @scope.ScopeIntent,
  registry : @registry.Registry,
) -> Array[String] {
  let failures : Array[String] = []
  let known = intent.selection.requirements.map(row => row.behavior_id)
  let seen : Set[String] = Set([])
  for boundary in intent.boundaries {
    if !known.contains(boundary.behavior_id) {
      failures.push(
        "scope replacement has no old obligation: " + boundary.behavior_id,
      )
    }
    if seen.contains(boundary.behavior_id) {
      failures.push(
        "scope replacement repeats an old obligation: " + boundary.behavior_id,
      )
    }
    seen.add(boundary.behavior_id)
    if boundary.rejection_tests.is_empty() &&
      (
        boundary.replacement_behaviors.is_empty() ||
        (
          ci_scope_current_entry(registry, boundary.behavior_id) is Some(entry) &&
          entry.status == "boundary"
        )
      ) {
      failures.push(
        "scope mapping requires registered evidence and current rejection tests: " +
        boundary.behavior_id,
      )
    }
    for
      (kind, ids) in [
        ("replacement", boundary.replacement_behaviors),
        ("rejection", boundary.rejection_tests),
      ] {
      if ids.length() != sorted_unique(ids.copy()).length() {
        failures.push(
          "scope " +
          kind +
          " repeats a canonical target: " +
          boundary.behavior_id,
        )
      }
      for id in ids {
        match ci_scope_current_entry(registry, id) {
          None =>
            failures.push(
              "scope " +
              kind +
              " target must be a current canonical registry ID: " +
              id,
            )
          Some(entry) if entry.status == "unsupported" =>
            failures.push(
              "scope " + kind + " target cannot be unsupported: " + id,
            )
          _ => ()
        }
      }
    }
  }
  for requirement in intent.selection.requirements {
    let current = ci_scope_current_entry(registry, requirement.behavior_id)
    let same_binding = current is Some(entry) &&
      entry.command == requirement.command &&
      entry.case_id == requirement.case_id
    if !same_binding &&
      !intent.boundaries.any(boundary => {
        boundary.behavior_id == requirement.behavior_id &&
        !boundary.replacement_behaviors.is_empty()
      }) {
      failures.push(
        "old-side acceptance requires explicit replacement for missing, moved command or moved case binding: " +
        requirement.behavior_id +
        " [" +
        requirement.command +
        "]",
      )
    }
  }
  failures
}

///|
/// Only fully mapped old commands absent from the current registry can leave
/// the current-command projection. New or edited files under that name stay gated.
fn ci_scope_retired_commands(
  intent : @scope.ScopeIntent,
  registry : @registry.Registry,
) -> Array[String] {
  if !ci_scope_mapping_errors(intent, registry).is_empty() {
    return []
  }
  intent.selection.commands.filter(command => {
    if command == "" ||
      command == "all" ||
      registry.entries.any(entry => entry.command == command) {
      return false
    }
    let old = intent.selection.requirements.filter(row => row.command == command)
    if old.is_empty() ||
      !old.all(row => {
        intent.boundaries.any(mapping => {
          mapping.behavior_id == row.behavior_id &&
          !mapping.replacement_behaviors.is_empty()
        })
      }) {
      return false
    }
    let directory = "commands/" + command
    !intent.changes.any(change => {
      change.new_path == directory ||
      change.new_path.has_prefix(directory + "/")
    })
  })
}

///|
fn ci_scope_prove_requirement(
  requirement : @scope.BehaviorRequirement,
  entry : @registry.RegistryEntry,
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
  bundles : ArrayView[EvidenceBundle],
  platforms : Array[String],
) -> Array[String] {
  let records = declaration.coverage.filter(record => {
    find_entry(registry, record.behavior_id) is Some(canonical) &&
    canonical.behavior_id == entry.behavior_id
  })
  guard records is [record] else {
    return [
      "scope evidence requires exactly one coverage record for current target: " +
      entry.behavior_id,
    ]
  }
  guard !requirement.backends.is_empty() && !requirement.evidence.is_empty() else {
    return [
      "scope obligation has no executable backend or evidence: " +
      requirement.behavior_id,
    ]
  }
  let required_entry = {
    ..entry,
    required_backends: requirement.backends,
    required_evidence: requirement.evidence,
    observations: requirement.observations,
    platforms: requirement.platforms,
    oracle_profile: requirement.oracle_profile,
  }
  let scoped_registry = { ..registry, entries: [required_entry], }
  let scoped_declaration = {
    ..declaration,
    affected_commands: if entry.command == "" {
      []
    } else {
      [entry.command]
    },
    affected_behaviors: [entry.behavior_id],
    coverage: [
      {
        ..record,
        behavior_id: entry.behavior_id,
        backends: requirement.backends,
        evidence: requirement.evidence,
        observations: requirement.observations,
      },
    ],
    required_backends: [],
    required_evidence: [],
    required_observations: [],
    // A current boundary must not replace the old obligation's evidence class.
    boundaries: [],
    deferred: [],
  }
  validate_report_evidence(
    scoped_declaration,
    scoped_registry,
    bundles,
    platforms~,
  )
}

///|
fn validate_scope_requirements(
  intent : @scope.ScopeIntent,
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
  bundles : ArrayView[EvidenceBundle],
  platforms : Array[String],
) -> Array[String] {
  let failures = ci_scope_mapping_errors(intent, registry)
  if !failures.is_empty() {
    return failures
  }
  for requirement in intent.selection.requirements {
    let boundary = intent.boundaries
      .iter()
      .find_first(boundary => {
        boundary.behavior_id == requirement.behavior_id &&
        !boundary.replacement_behaviors.is_empty()
      })
    let targets = match boundary {
      Some(boundary) => boundary.replacement_behaviors
      None => [requirement.behavior_id]
    }
    for id in targets {
      guard ci_scope_current_entry(registry, id) is Some(entry) else {
        failures.push("scope replacement target disappeared: " + id)
        continue
      }
      // A different owner or case identity requires the explicit mapping above.
      if boundary is None &&
        (
          entry.command != requirement.command ||
          entry.case_id != requirement.case_id
        ) {
        failures.push(
          "scope evidence cannot borrow another command or case binding's current row: " +
          id,
        )
        continue
      }
      // A removed rejection is proved by the mapped supported operation.
      // Its old backend/platform/observation obligations still apply below.
      let current_rejection = ci_scope_current_entry(
          registry,
          requirement.behavior_id,
        )
        is Some(current) &&
        current.status == "boundary"
      let old_requirement = if boundary is Some(_) &&
        !current_rejection &&
        requirement.evidence.contains("boundary") &&
        entry.status == "supported" {
        {
          ..requirement,
          evidence: sorted_unique(
            requirement.evidence.map(kind => {
              if kind == "boundary" {
                "contract"
              } else {
                kind
              }
            }),
          ),
        }
      } else {
        requirement
      }
      failures.append(
        ci_scope_prove_requirement(
          old_requirement, entry, declaration, registry, bundles, platforms,
        ).map(problem => {
          "scope old obligation " +
          requirement.behavior_id +
          " [" +
          requirement.command +
          "] via " +
          id +
          ": " +
          problem
        }),
      )
    }
  }
  let checked : Set[String] = Set([])
  for boundary in intent.boundaries {
    for id in ci_scope_mapped_targets(intent, boundary.behavior_id) {
      if checked.contains(id) {
        continue
      }
      checked.add(id)
      guard ci_scope_current_entry(registry, id) is Some(entry) else {
        failures.push("scope mapped current target disappeared: " + id)
        continue
      }
      let current : @scope.BehaviorRequirement = {
        behavior_id: entry.behavior_id,
        case_id: entry.case_id,
        command: entry.command,
        backends: entry.required_backends,
        evidence: entry.required_evidence,
        observations: entry.observations,
        platforms: entry.platforms,
        oracle_profile: entry.oracle_profile,
      }
      failures.append(
        ci_scope_prove_requirement(
          current, entry, declaration, registry, bundles, platforms,
        ).map(problem => {
          "scope mapped current obligation " + id + ": " + problem
        }),
      )
    }
  }
  failures
}
