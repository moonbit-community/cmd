///|
fn panel_test_report(metric : Json, args~ : Array[String] = []) -> Json raise {
  let workload : FunctionalWorkload = @json.from_json({
    "id": "required",
    "command": "cat",
    "reference_behavior_id": "case:cat",
    "recipe": "real-input",
    "args": Json(args),
  })
  let row = {
    ..failed_functional_row(workload, ""),
    status: "checked",
    probe: Some(metric),
  }
  // Exercise the actual producer's derived field encoding, not a hand-written
  // approximation of Option's standalone JSON representation.
  { "passed": true, "artifact_integrity": true, "rows": ToJson::to_json([row]) }
}

///|
test "required panels consume actual serialized rows and reject independent gate failures" {
  let metric : Json = {
    "complete": true,
    "passed": true,
    "candidate_median_us": 10.0,
    "upstream_median_us": 10.0,
  }
  let report = panel_test_report(metric)
  assert_true(
    report is { "rows": [{ "probe": { "complete": True, .. }, .. }], .. },
  )
  assert_true(
    combine_panel_windows(report, report, ["required"], true)
    is { "passed": True, .. },
  )
  assert_true(
    combine_panel_windows(report, report, [], true) is { "passed": False, .. },
  )
  assert_true(
    combine_panel_windows(report, report, ["missing"], true)
    is { "passed": False, .. },
  )
  assert_true(
    combine_panel_windows(
      report,
      panel_test_report(metric, args=["changed"]),
      ["required"],
      true,
    )
    is { "passed": False, .. },
  )
  for
    changed in [
      (
        {
          "complete": true,
          "passed": true,
          "candidate_median_us": 10.6,
          "upstream_median_us": 10.0,
        } : Json),
      (
        {
          "complete": true,
          "passed": false,
          "candidate_median_us": 10.0,
          "upstream_median_us": 10.0,
        } : Json),
      (
        {
          "complete": false,
          "passed": true,
          "candidate_median_us": 10.0,
          "upstream_median_us": 10.0,
        } : Json),
      (
        {
          "complete": true,
          "passed": true,
          "candidate_median_us": 0.0,
          "upstream_median_us": 10.0,
        } : Json),
    ] {
    let rejected = panel_test_report(changed)
    assert_true(
      combine_panel_windows(rejected, rejected, ["required"], true)
      is { "passed": False, .. },
    )
  }
  let drifted = panel_test_report({
    "complete": true,
    "passed": true,
    "candidate_median_us": 12.0,
    "upstream_median_us": 10.0,
  })
  assert_true(
    combine_panel_windows(report, drifted, ["required"], false)
    is { "passed": False, .. },
  )
  guard report is Object(fields) && fields["rows"] is Array(rows) else {
    fail("invalid actual report")
  }
  for
    rejected in [
      (
        { "passed": false, "artifact_integrity": true, "rows": Json(rows) } :
        Json),
      (
        { "passed": true, "artifact_integrity": false, "rows": Json(rows) } :
        Json),
      (
        {
          "passed": true,
          "artifact_integrity": true,
          "rows": [rows[0], rows[0]],
        } : Json),
    ] {
    assert_true(
      combine_panel_windows(rejected, report, ["required"], true)
      is { "passed": False, .. },
    )
  }
}
