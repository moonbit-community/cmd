///|
/// Every selected case must terminate exactly once, including platform skips.
pub fn result_integrity_errors(
  selected : ArrayView[Case],
  reports : ArrayView[CaseReport],
) -> Array[String] {
  let errors : Array[String] = []
  let expected : Map[String, Case] = Map([])
  let seen : Set[String] = Set([])
  if selected.is_empty() {
    errors.push("empty required selection")
  }
  for fixture in selected {
    if expected.contains(fixture.id) {
      errors.push("duplicate selected case: " + fixture.id)
    }
    expected[fixture.id] = fixture
  }
  for report in reports {
    if seen.contains(report.id) {
      errors.push("duplicate result: " + report.id)
    }
    seen.add(report.id)
    if !["pass", "fail", "skip", "infra"].contains(report.result) {
      errors.push("unknown result status: " + report.id)
    }
    match expected.get(report.id) {
      Some(fixture) => {
        if report.command != fixture.command {
          errors.push("result command differs: " + report.id)
        }
        if report.result == "skip" && fixture.platform_applies() {
          errors.push("undeclared platform skip: " + report.id)
        }
        if report.result == "pass" && !report.missing_observations.is_empty() {
          errors.push(
            "passing result lacks required observations: " + report.id,
          )
        }
      }
      None =>
        if !(report.result == "infra" && report.id.has_prefix("runner:")) &&
          !(published_mode() &&
          report.verification == "availability" &&
          report.id == "published-resolution:" + report.command) {
          errors.push("unselected result: " + report.id)
        }
    }
  }
  for fixture in selected {
    if !seen.contains(fixture.id) {
      errors.push("missing required result: " + fixture.id)
    }
  }
  errors
}
