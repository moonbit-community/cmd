///|
fn proof_case_applies(fixture : @testkit.Case, platform : String) -> Bool {
  match fixture.host_platforms {
    None => true
    Some(names) =>
      names.contains(platform) ||
      (platform != "windows" && names.contains("posix"))
  }
}

///|
fn join_proof_results(
  manifest : Json,
  index : @registry.Registry,
  cases : Array[@testkit.Case],
  selected : Array[@testkit.Case],
  results : Array[Json],
  platform : String,
  scenario_catalog~ : Json = Json::null(),
  scenario_receipts~ : Json = Json::null(),
) -> Json {
  let verdicts : Array[Json] = []
  let mut complete = true
  let mut all_qualified = true
  let mut executed_claims = 0
  let mut reviewed = 0
  let mut unresolved = 0
  let mut unresolved_features = 0
  for obligation in proof_array(proof_field(manifest, "obligations")) {
    let id = proof_text(proof_field(obligation, "claim_id"))
    if proof_field(obligation, "reviewed") != Json(true) {
      unresolved += 1
      if proof_field(obligation, "feature") == Json(true) {
        unresolved_features += 1
      }
      continue
    }
    reviewed += 1
    let command = proof_text(proof_field(obligation, "command"))
    let details : Array[Json] = []
    let mut passed = true
    let mut applicable = 0
    let mut excluded = 0
    for requested in proof_array(proof_field(obligation, "case_ids")) {
      guard proof_binding(index, proof_text(requested), command) is Some(entry) else {
        passed = false
        continue
      }
      let metadata = entry.implementation == "metadata-probe"
      let canonical = if metadata { entry.behavior_id } else { entry.case_id }
      let observations = ["status", "stdout", "stderr"]
      if metadata &&
        !selected.any(item => item.id == canonical && item.command == command) {
        passed = false
        continue
      }
      if !metadata {
        guard cases.filter(item => {
            item.id == canonical && item.command == command
          })
          is [fixture] else {
          passed = false
          continue
        }
        if !proof_case_applies(fixture, platform) {
          excluded += 1
          details.push({
            "case": canonical,
            "applicability": "excluded by explicit source-case platform",
            "qualified": false,
          })
          continue
        }
        observations.append(@testkit.contract_observations(fixture))
        let actual = selected.filter(item => {
          item.id == canonical && item.command == command
        })
        if !(actual is [definition] &&
          ToJson::to_json(definition) == ToJson::to_json(fixture)) {
          passed = false
          details.push({
            "case": canonical,
            "passed": false,
            "reason": "actual executed definition missing or differs from reviewed source",
          })
          continue
        }
      }
      applicable += 1
      let matches = results.filter(row => {
        proof_field(row, "id") == Json(canonical) &&
        proof_field(row, "command") == Json(command) &&
        [Json("contract"), Json("boundary")].contains(
          proof_field(row, "verification"),
        )
      })
      let ok = match matches {
        [result] =>
          proof_field(result, "result") == Json("pass") &&
          proof_field(result, "platform") == Json(platform) &&
          proof_field(result, "backend") == Json("wasm") &&
          proof_field(result, "missing_observations") == Json::array([]) &&
          observations.all(name => {
            proof_array(proof_field(result, "observations")).contains(
              Json(name),
            )
          }) &&
          (
            !metadata ||
            (
              proof_array(proof_field(result, "observations")).contains(
                Json("stdin-unread"),
              ) &&
              proof_text(proof_field(result, "detail")).contains(
                "help=true version=true",
              )
            )
          )
        _ => false
      }
      passed = passed && ok
      details.push({ "case": canonical, "passed": ok })
    }
    for binding in proof_array(proof_field(obligation, "scenario_bindings")) {
      let result = proof_scenario_result(
        binding, command, index, cases, selected, results, scenario_catalog, scenario_receipts,
        platform,
      )
      details.push(result)
      if proof_field(result, "excluded") == Json(true) {
        excluded += 1
      } else {
        applicable += 1
        passed = passed && proof_field(result, "passed") == Json(true)
      }
    }
    if applicable == 0 {
      passed = false
    }
    if applicable > 0 {
      executed_claims += 1
    }
    complete = complete &&
      (
        passed ||
        (applicable == 0 && excluded > 0 && details.length() == excluded)
      )
    all_qualified = all_qualified && passed && excluded == 0
    verdicts.push({
      "claim_id": id,
      "passed": passed,
      "qualified": passed && excluded == 0,
      "applicable_cases": applicable,
      "excluded_cases": excluded,
      "scope": proof_field(obligation, "scope"),
      "activation": proof_field(obligation, "activation"),
      "remaining_facets": proof_field(obligation, "remaining_facets"),
      "cases": details,
    })
  }
  if reviewed == 0 || executed_claims == 0 {
    complete = false
  }
  {
    "reviewed_profile_passed": complete,
    "reviewed_definitions": reviewed,
    "executed_claims": executed_claims,
    "unresolved_obligations": unresolved,
    "unresolved_catalog_claims": unresolved - unresolved_features,
    "unresolved_primary_features": unresolved_features,
    "full_catalog_qualified": complete && all_qualified && unresolved == 0,
    "general_compatibility_proof": false,
    "platform": platform,
    "rows": verdicts,
  }
}
