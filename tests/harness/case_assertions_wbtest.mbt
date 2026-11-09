///|
fn assertion_case(value : Json) -> Case raise {
  let base : Map[String, Json] = {
    "id": Json("assertions"),
    "command": Json("probe"),
    "args": Json::array([]),
    "files": Json::array([]),
    "environment": Json::object({}),
    "expected_status": Json(0),
    "normalizations": Json::array([]),
    "comparison": Json("contract"),
  }
  guard value is Object(fields) else {
    fail("assertion test requires an object")
  }
  for name, value in fields {
    base[name] = value
  }
  @json.from_json(Json(base))
}

///|
test "local assertions reject status-only and newline-only expectations" {
  for
    fixture in [
      assertion_case({}),
      assertion_case({
        "expected_stdout_ends_with_newline": true,
        "expected_stderr_ends_with_newline": true,
      }),
    ] {
    assert_false(case_assertion_errors(fixture).is_empty())
  }
  let silent = assertion_case({
    "expected_stdout_text": "",
    "expected_stderr_hex": "",
  })
  assert_eq(case_assertion_errors(silent), [])
  assert_true(
    case_assertion_errors({ ..silent, comparison: None, }).contains(
      "independent stream assertions are not executed locally",
    ),
  )
}

///|
test "finite diagnostics require an explicit reason and exact other stream" {
  let partial = assertion_case({
    "expected_status": 1,
    "expected_stdout_text": "",
    "expected_stderr_contains": "permission denied",
    "diagnostic_reason": "The operating system supplies the final path wording.",
  })
  assert_eq(case_assertion_errors(partial), [])
  for
    fixture in [
      { ..partial, diagnostic_reason: None, },
      {
        ..partial,
        expected_stdout_text: None,
        expected_stdout_contains: Some("record"),
      },
      {
        ..partial,
        expected_rejection: Some("permission denied"),
        expected_status: 0,
      },
    ] {
    assert_false(case_assertion_errors(fixture).is_empty())
  }
  for fragment in ["", "\n", ":"] {
    assert_false(
      case_assertion_errors({
        ..partial,
        expected_stderr_contains: Some(fragment),
      }).is_empty(),
    )
  }
}

///|
test "scenario definitions require the actual dispatch registration" {
  let scenario = assertion_case({ "comparison": "scenario" })
  assert_false(case_assertion_errors(scenario).is_empty())
  assert_false(
    case_assertion_errors(scenario, scenario_ids=["unrelated"]).is_empty(),
  )
  assert_eq(case_assertion_errors(scenario, scenario_ids=[scenario.id]), [])
  let ordinary = assertion_case({})
  assert_false(
    case_assertion_errors(ordinary, scenario_ids=[ordinary.id]).is_empty(),
  )
}

///|
test "complete runtime expectations cannot be replaced by familiar case names" {
  let fixture = assertion_case({
    "expected_stdout_json": { "count": 2 },
    "expected_stderr_text": "",
  })
  assert_eq(case_assertion_errors(fixture), [])
  for id in ["rg-json", "o12-linux-directory-size"] {
    assert_false(
      case_assertion_errors({
        ..fixture,
        id,
        expected_stdout_json: None,
        expected_stdout_contains: Some("match"),
        diagnostic_reason: Some(
          "A label does not supply complete expected output.",
        ),
      }).is_empty(),
    )
  }
  assert_false(
    case_assertion_errors({
      ..fixture,
      expected_stderr_text: None,
      expected_stderr_contains: Some("diagnostic"),
      diagnostic_reason: Some("Runtime stdout still requires exact stderr."),
    }).is_empty(),
  )
}
