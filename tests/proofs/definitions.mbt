///|
fn proof_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn proof_array(value : Json) -> Array[Json] {
  match value {
    Array(rows) => rows
    _ => []
  }
}

///|
fn proof_text(value : Json) -> String {
  match value {
    String(text) => text
    _ => ""
  }
}

///|
fn proof_binding(
  index : @registry.Registry,
  id : String,
  command : String,
) -> @registry.RegistryEntry? {
  if id.is_empty() {
    return None
  }
  let matches = index.entries.filter(entry => {
    entry.command == command &&
    (
      entry.case_id == id ||
      entry.behavior_id == id ||
      entry.aliases.contains(id)
    )
  })
  if matches is [entry] {
    Some(entry)
  } else {
    None
  }
}

///|
fn proof_definitions_errors(
  manifest : Json,
  index : @registry.Registry,
  cases : Array[@testkit.Case],
  catalog : Array[@contracts.CommandContract],
  scenario_catalog~ : Json = Json::null(),
) -> Array[String] {
  let errors : Array[String] = []
  let rows = proof_array(proof_field(manifest, "obligations"))
  if proof_field(manifest, "schema") != Json(1) || rows.is_empty() {
    errors.push("missing/invalid proof definition schema or empty obligations")
  }
  let required : Set[String] = Set([])
  for command in catalog {
    for claim in command.options {
      required.add(command.name + ":" + claim)
    }
  }
  let seen : Set[String] = Set([])
  for row in rows {
    let id = proof_text(proof_field(row, "claim_id"))
    let command = proof_text(proof_field(row, "command"))
    let feature = proof_field(row, "feature") == Json(true)
    let kind = proof_text(proof_field(row, "kind"))
    if !["metadata", "contract", "boundary", "unresolved", "supported-option"].contains(
        kind,
      ) ||
      ![Json(true), Json(false)].contains(proof_field(row, "reviewed")) {
      errors.push("missing/invalid review state or obligation kind: " + id)
    }
    if !id.has_prefix(command + ":") ||
      (
        feature &&
        (!id.has_prefix(command + ":feature/") || required.contains(id))
      ) {
      errors.push(
        "claim identity does not belong to its declared command: " + id,
      )
    }
    if id.is_empty() ||
      seen.contains(id) ||
      (!feature && !required.contains(id)) ||
      !catalog.any(item => item.name == command) {
      errors.push("unknown, empty or duplicate coverage claim: " + id)
    }
    seen.add(id)
    if proof_field(row, "reviewed") != Json(true) {
      continue
    }
    let bindings = proof_array(proof_field(row, "case_ids"))
    let scenarios = proof_array(proof_field(row, "scenario_bindings"))
    let metadata_claim = id == command + ":help" || id == command + ":version"
    if metadata_claim != (kind == "metadata") {
      errors.push("metadata claim and observer kind must agree: " + id)
    }
    if (bindings.is_empty() && scenarios.is_empty()) ||
      proof_text(proof_field(row, "activation")).trim().length() < 16 ||
      proof_text(proof_field(row, "scope")).trim().is_empty() {
      errors.push(
        "reviewed obligation requires activation, explicit scope and cases: " +
        id,
      )
    }
    let bound_scenarios : Set[String] = Set([])
    for binding in scenarios {
      let scene = proof_text(proof_field(binding, "case_id"))
      if bound_scenarios.contains(scene) {
        errors.push(
          "duplicate required scenario binding: " + id + " -> " + scene,
        )
      }
      bound_scenarios.add(scene)
      let ids = proof_array(proof_field(binding, "assertions"))
      if metadata_claim ||
        !index.entries.any(entry => {
          entry.behavior_id == "scenario:" + scene &&
          entry.implementation == "stateful-scenario"
        }) ||
        !cases.any(fixture => {
          fixture.id == scene && fixture.comparison == Some("scenario")
        }) {
        errors.push(
          "scenario binding has no registered current procedural case: " +
          id +
          " -> " +
          scene,
        )
      }
      guard @testkit.scenario_definition(scenario_catalog, scene)
        is Some(definition) else {
        errors.push(
          "scenario binding lacks typed assertion descriptors: " + scene,
        )
        continue
      }
      if ids.is_empty() {
        errors.push("scenario binding cannot select zero assertions: " + id)
      }
      let names : Set[String] = Set([])
      for assertion in ids {
        let name = proof_text(assertion)
        if name.is_empty() || names.contains(name) {
          errors.push("empty/duplicate scenario assertion binding: " + id)
        }
        names.add(name)
        let matches = proof_array(proof_field(definition, "assertions")).filter(item => {
            proof_field(item, "id") == Json(name) &&
            proof_field(item, "command") == Json(command)
          },
        )
        if !(matches is [item] &&
          !proof_array(proof_field(item, "observations")).is_empty() &&
          [Json("equal"), Json("equal-pair")].contains(
            proof_field(item, "relation"),
          )) {
          errors.push(
            "missing or cross-command assertion descriptor: " +
            id +
            " -> " +
            name,
          )
        }
      }
    }
    let bound : Set[String] = Set([])
    for value in bindings {
      let requested = proof_text(value)
      guard proof_binding(index, requested, command) is Some(entry) else {
        errors.push(
          "missing/cross-command proof binding: " + id + " -> " + requested,
        )
        continue
      }
      let canonical = if entry.is_case() {
        entry.case_id
      } else {
        entry.behavior_id
      }
      if bound.contains(canonical) {
        errors.push("aliased duplicate proof binding: " + id)
      }
      bound.add(canonical)
      if entry.implementation == "metadata-probe" {
        if proof_text(proof_field(row, "kind")) != "metadata" ||
          !(id == command + ":help" || id == command + ":version") {
          errors.push("metadata cannot prove operational semantics: " + id)
        }
        continue
      }
      if kind == "metadata" {
        errors.push(
          "metadata obligations require the typed stdin-preserving metadata observer: " +
          id,
        )
      }
      guard cases.filter(item => {
          item.id == entry.case_id && item.command == command
        })
        is [fixture] else {
        errors.push("proof binding requires one actual case definition: " + id)
        continue
      }
      errors.append(
        @testkit.contract_errors(fixture).map(error => id + ": " + error),
      )
      if fixture.comparison != Some("contract") &&
        fixture.comparison != Some("boundary") {
        errors.push(
          "portable proof requires an asserted contract, not differential-only execution: " +
          id,
        )
      }
      if !proof_exact_streams(fixture) {
        errors.push(
          "proof requires exact stdout and stderr contracts in this profile: " +
          id,
        )
      }
    }
  }
  for id in required {
    if !seen.contains(id) {
      errors.push("unaccounted catalog claim: " + id)
    }
  }
  errors
}
