///|
fn proof_exact_streams(fixture : @testkit.Case) -> Bool {
  [Some("contract"), Some("boundary")].contains(fixture.comparison) &&
  (
    fixture.expected_stdout_text is Some(_) ||
    fixture.expected_stdout_hex is Some(_)
  ) &&
  (
    fixture.expected_stderr_text is Some(_) ||
    fixture.expected_stderr_hex is Some(_)
  )
}

///|
async fn generate_proof_obligations() -> Unit {
  let index = @registry.load("tests/registry/registry.json")
  let cases = proof_load_cases(index)
  let annotations : Array[Json] = []
  let features : Array[Json] = []
  for
    path in [
      "tests/registry/coverage-reviewed.json", "tests/registry/coverage-systems.json",
    ] {
    let data = @json.parse(@fs.read_file(path).text())
    annotations.append(proof_array(proof_field(data, "claims")))
    features.append(proof_array(proof_field(data, "features")))
  }
  let catalog = @contracts.command_catalog()
  let scenario_catalog = @json.parse(
    @fs.read_file("tests/registry/scenario-proofs.json").text(),
  )
  let scenario_errors = @testkit.scenario_catalog_errors(scenario_catalog)
  guard scenario_errors.is_empty() else { fail(scenario_errors.join("\n")) }
  let obligations : Array[Json] = []
  for command in catalog {
    for claim in command.options {
      let id = command.name + ":" + claim
      let matches = annotations.filter(row => {
        proof_field(row, "command") == Json(command.name) &&
        proof_field(row, "claim") == Json(claim)
      })
      guard matches.length() <= 1 else {
        fail("independent annotations overlap; review before combining: " + id)
      }
      if ["help", "version"].contains(claim) {
        obligations.push({
          "claim_id": id,
          "command": command.name,
          "kind": "metadata",
          "reviewed": true,
          "case_ids": ["metadata:" + command.name],
          "activation": "Shared typed observer checks exact standalone metadata, status0, empty stderr and final LF; after child completion a nonempty inherited stdin marker must remain unread.",
          "scope": "standalone workspace metadata only; published coordinates use independent frozen expectations",
          "remaining_facets": ["metadata combinations and ordinary operands"],
        })
      } else {
        obligations.push(
          proof_obligation(
            id,
            command.name,
            matches,
            cases,
            false,
            scenario_catalog,
          ),
        )
      }
    }
  }
  for feature in features {
    let command = proof_text(proof_field(feature, "command"))
    obligations.push(
      proof_obligation(
        command + ":feature/" + proof_text(proof_field(feature, "claim")),
        command,
        [feature],
        cases,
        true,
        scenario_catalog,
      ),
    )
  }
  let result : Json = {
    "schema": 1,
    "profile": "finite independently reviewed current contract definitions; execution must be joined separately",
    "full_semantic_exhaustiveness": false,
    "catalog_claims": catalog.fold(init=0, (sum, command) => {
      sum + command.options.length()
    }),
    "commands": Json(catalog.map(command => command.name)),
    "obligations": obligations,
  }
  let errors = proof_definitions_errors(
    result,
    index,
    cases,
    catalog,
    scenario_catalog~,
  )
  guard errors.is_empty() else { fail(errors.join("\n")) }
  @fs.write_file(
    "tests/registry/coverage.json",
    result.stringify(indent=2) + "\n",
  )
  println(
    "Coverage obligations generated; reviewed definitions are not execution passes",
  )
}

///|
fn proof_obligation(
  id : String,
  command : String,
  matches : Array[Json],
  cases : Array[@testkit.Case],
  feature : Bool,
  scenario_catalog : Json,
) -> Json {
  let original = if matches is [row] { row } else { Json::null() }
  let kind = proof_text(proof_field(original, "kind"))
  let ids : Array[String] = []
  let scenario_bindings = proof_array(
    proof_field(original, "scenario_bindings"),
  )
  let unsupported : Array[Json] = []
  for binding in proof_array(proof_field(original, "case_ids")) {
    let id = proof_text(binding)
    if scenario_bindings.any(binding => {
        proof_field(binding, "case_id") == Json(id)
      }) {
      if !cases.any(fixture => {
          fixture.id == id && fixture.comparison == Some("scenario")
        }) ||
        @testkit.scenario_definition(scenario_catalog, id) is None {
        unsupported.push({
          "case_id": id,
          "reason": "scenario binding has no current typed definition",
        })
      }
    } else if cases.filter(fixture => {
        fixture.id == id && fixture.command == command
      })
      is [fixture] &&
      proof_exact_streams(fixture) {
      ids.push(id)
    } else {
      unsupported.push({
        "case_id": id,
        "reason": "required companion lacks an exact independently reviewed contract or typed scenario binding",
      })
    }
  }
  let active = ![
    "accepted-option-nondistinguishing-fixture", "accepted-option-timing-unmeasured",
    "option-interaction-only",
  ].contains(kind)
  let reviewed = active &&
    (!ids.is_empty() || !scenario_bindings.is_empty()) &&
    unsupported.is_empty() &&
    proof_field(original, "disposition") == Json("reviewed-definition")
  {
    "claim_id": id,
    "command": command,
    "feature": feature,
    "kind": if !reviewed {
      "unresolved"
    } else if kind == "explicit-rejection-boundary" {
      "boundary"
    } else {
      "contract"
    },
    "reviewed": reviewed,
    "case_ids": if reviewed {
      Json(ids)
    } else {
      proof_field(original, "case_ids")
    },
    "activation": if original == Json::null() {
      "No independently reviewed discriminating exact contract is currently bound; tags and argv presence are discovery only."
    } else {
      proof_field(original, "activation")
    },
    "scenario_bindings": Json(scenario_bindings),
    "unqualified_bindings": unsupported,
    "scope": "Only the stated finite facet is reviewed. Definition kind: " +
    kind +
    ". Every named binding is required. Exact streams and typed scenario observations prove only the stated facet; unqualified companions are never silently dropped.",
    "remaining_facets": [
      "other spellings, boundaries, interactions and error ordering",
      "resource and lifecycle effects not asserted by these cases",
      ..proof_array(proof_field(original, "remaining_facets")),
    ],
    "execution_requirements": [
      "fresh same-run applicable-platform results", "every required exact or typed-scenario binding must pass",
    ],
  }
}
