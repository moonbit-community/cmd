///|
fn proof_scenario_result(
  binding : Json,
  command : String,
  index : @registry.Registry,
  cases : Array[@testkit.Case],
  selected : Array[@testkit.Case],
  results : Array[Json],
  catalog : Json,
  receipts : Json,
  platform : String,
) -> Json {
  let id = proof_text(proof_field(binding, "case_id"))
  let rejected = fn(reason : String) -> Json {
    { "case": id, "passed": false, "excluded": false, "reason": reason }
  }
  guard index.entries.any(entry => {
      entry.behavior_id == "scenario:" + id &&
      entry.implementation == "stateful-scenario"
    }) &&
    cases.filter(fixture => {
      fixture.id == id && fixture.comparison == Some("scenario")
    })
    is [fixture] else {
    return rejected("missing registered procedural case")
  }
  if !proof_case_applies(fixture, platform) {
    return {
      "case": id,
      "passed": false,
      "qualified": false,
      "excluded": true,
      "reason": "explicit source-case platform exclusion",
    }
  }
  guard selected.filter(item => item.id == id && item.command == fixture.command)
    is [actual] &&
    ToJson::to_json(actual) == ToJson::to_json(fixture) else {
    return rejected("actual executed scenario case definition differs")
  }
  let report = results.filter(row => {
    proof_field(row, "id") == Json(id) &&
    proof_field(row, "command") == Json(fixture.command) &&
    proof_field(row, "verification") == Json("contract")
  })
  guard report is [row] &&
    proof_field(row, "result") == Json("pass") &&
    proof_field(row, "stage") == Json("complete") &&
    proof_field(row, "platform") == Json(platform) &&
    proof_field(row, "backend") == Json("wasm") &&
    proof_field(row, "missing_observations") == Json::array([]) else {
    return rejected(
      "scenario must have exactly one complete actual same-platform Wasm contract pass",
    )
  }
  guard @testkit.scenario_definition(catalog, id) is Some(definition) else {
    return rejected("typed scenario descriptors are missing")
  }
  let actual_receipts = proof_array(proof_field(receipts, "scenarios")).filter(receipt => {
    proof_field(receipt, "case_id") == Json(id)
  })
  guard proof_field(receipts, "schema") == Json(1) &&
    actual_receipts is [receipt] else {
    return rejected("missing or duplicate actual scenario receipt")
  }
  let ids = proof_array(proof_field(binding, "assertions")).map(proof_text)
  let errors = @testkit.scenario_receipt_errors(definition, receipt)
  errors.append(
    @testkit.scenario_receipt_errors(
      definition,
      receipt,
      required=ids,
      command~,
    ),
  )
  {
    "case": id,
    "passed": errors.is_empty(),
    "excluded": false,
    "assertions": Json(ids),
    "errors": Json(errors),
  }
}
