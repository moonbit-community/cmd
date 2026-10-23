///|
fn ci_scope_declaration_errors(
  intent : @scope.ScopeIntent,
  declaration : ChangeDeclaration,
  registry : @registry.Registry,
) -> Array[String] {
  let failures = ci_scope_mapping_errors(intent, registry)
  let required = ci_scope_impact(intent, registry=Some(registry))
  for
    (name, minimum, supplied) in [
      ("commands", required.affected_commands, declaration.affected_commands),
      (
        "behaviors",
        required.affected_behaviors,
        canonical_ids(registry, declaration.affected_behaviors),
      ),
      (
        "options",
        required.affected_options,
        declaration.affected_options.unwrap_or([]),
      ),
      (
        "operands",
        required.affected_operands,
        declaration.affected_operands.unwrap_or([]),
      ),
      ("cases", required.case_ids, declaration.case_ids.unwrap_or([])),
    ] {
    for id in minimum {
      if !supplied.contains(id) {
        failures.push(
          "local declaration omits automatic/reviewed " + name + ": " + id,
        )
      }
    }
  }
  if required.core_impact is Some(_) &&
    declaration.core_impact != required.core_impact {
    failures.push("local declaration narrows automatic core impact")
  }
  if required.published_manifest_affected &&
    declaration.published_manifest_affected != Some(true) {
    failures.push("local declaration omits published manifest impact")
  }
  if canonical_ids(registry, declaration.deferred) !=
    canonical_ids(registry, required.deferred) ||
    sorted_unique(declaration.uncovered.unwrap_or([])) !=
    sorted_unique(required.uncovered.copy()) {
    failures.push(
      "local declaration changes reviewed deferrals or uncovered obligations",
    )
  }
  for boundary in required.boundaries {
    if !declaration.boundaries.any(supplied => {
        supplied.behavior_id == boundary.behavior_id &&
        supplied.support_record == boundary.support_record &&
        supplied.adr == boundary.adr &&
        supplied.current_limit == boundary.current_limit &&
        supplied.unlock_condition == boundary.unlock_condition
      }) {
      failures.push(
        "local declaration omits reviewed ADR/support/unlock mapping: " +
        boundary.behavior_id,
      )
    }
  }
  failures
}

///|
// The command-line/push entry uses fresh automatic scope. The earlier public
// audit(options) remains the low-level protocol used by controlled fixtures;
// it cannot be selected as an alternate mode by the push launcher.
async fn audit_scoped(options : AuditOptions) -> AuditReport {
  let root = ci_git(["rev-parse", "--show-toplevel"])
  let intent = @scope.verify_checkout_intent(
    root,
    options.base,
    options.head,
    "local",
  )
  let registry = @registry.load(options.registry_path)
  let declaration : ChangeDeclaration = parse_json_file(
    options.declaration_path,
  )
  let failures = ci_scope_declaration_errors(intent, declaration, registry)
  guard failures.is_empty() else { fail(failures.join("\n")) }
  audit_declared(options, declaration, scope=Some(intent))
}
