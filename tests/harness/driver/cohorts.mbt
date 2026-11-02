///|
fn metadata_cases() -> Array[@harness.Case] raise {
  @contracts.command_catalog().map(contract => {
    @json.from_json({
      "id": "metadata:" + contract.name,
      "command": contract.name,
      "args": [],
      "files": [],
      "environment": {},
      "normalizations": [],
      "expected_status": 0,
      "comparison": "metadata",
    })
  })
}

///|
fn case_in_suites(fixture : @harness.Case, suites : Array[String]) -> Bool {
  let kind = fixture.comparison.unwrap_or("differential")
  suites.any(suite => {
    match suite {
      "contract" => kind == "contract" || fixture.expected_rejection is Some(_)
      "oracle" =>
        kind == "differential" ||
        kind == "exact" ||
        kind == "normalized" ||
        fixture.oracle == Some(true) ||
        kind == "oracle-scenario"
      "scenarios" => kind == "scenario"
      _ => kind == suite
    }
  })
}
