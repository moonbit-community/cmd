///|
fn exact_stream(fixture : Case, stream : String) -> Bool {
  match stream {
    "stdout" =>
      fixture.expected_stdout_json is None &&
      (
        fixture.expected_stdout_hex is Some(_) ||
        (fixture.expected_stdout_text is Some(text) && !runtime_template(text))
      )
    _ =>
      fixture.expected_stderr_text is Some(_) ||
      fixture.expected_stderr_hex is Some(_)
  }
}

///|
// These two metadata cases execute the driver's complete help assertions.
fn has_runtime_output(fixture : Case) -> Bool {
  fixture.expected_stdout_json is Some(_) ||
  runtime_template(fixture.expected_stdout_text.unwrap_or("")) ||
  ["release-metadata-rg-help", "compat-catalog-line-277"].contains(fixture.id)
}

///|
// Inspect the actual expectations and dispatch registration directly. Runtime
// results, including scenario failures, are checked separately after execution.
fn case_assertion_errors(
  fixture : Case,
  scenario_ids~ : Array[String] = [],
) -> Array[String] {
  let errors = contract_errors(fixture)
  if fixture.expected_rejection is Some(_) && fixture.expected_status == 0 {
    errors.push("rejection requires an exact nonzero status")
  }
  if [Some("scenario"), Some("oracle-scenario")].contains(fixture.comparison) {
    if !scenario_ids.contains(fixture.id) {
      errors.push("scenario is not registered: " + fixture.id)
    }
    return errors
  }
  if fixture.comparison != Some("contract") &&
    fixture.expected_rejection is None {
    errors.push("independent stream assertions are not executed locally")
  }
  let dynamic = has_runtime_output(fixture)
  if !exact_stream(fixture, "stdout") && !dynamic {
    errors.push("stdout requires an exact or complete runtime expectation")
  }
  if !exact_stream(fixture, "stderr") {
    if dynamic {
      errors.push("runtime stdout requires exact stderr")
    } else {
      let fragments = fixture.expected_stderr_contains_all.unwrap_or([]).copy()
      if fixture.expected_stderr_contains is Some(fragment) {
        fragments.push(fragment)
      }
      if fragments.is_empty() ||
        fragments.any(value => value.trim().length() < 3) {
        errors.push("stderr requires a finite nonvacuous fragment assertion")
      }
    }
  }
  errors
}
