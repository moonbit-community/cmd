///|
fn quality_case(value : Json) -> Case raise {
  let base : Map[String, Json] = {
    "id": Json("quality"),
    "command": Json("probe"),
    "args": Json::array([]),
    "files": Json::array([]),
    "environment": Json::object({}),
    "expected_status": Json(0),
    "normalizations": Json::array([]),
    "comparison": Json("contract"),
  }
  guard value is Object(fields) else { fail("quality test requires an object") }
  for name, value in fields {
    base[name] = value
  }
  @json.from_json(Json(base))
}

///|
test "quality rejects status-only and newline-only local assertions" {
  let status_only = quality_case({})
  let newline_only = quality_case({
    "expected_stdout_ends_with_newline": true,
    "expected_stderr_ends_with_newline": true,
  })
  for fixture in [status_only, newline_only] {
    assert_eq(case_quality_kind(fixture), "missing")
    assert_false(case_quality_errors(fixture).is_empty())
  }
  let silent = quality_case({
    "expected_stdout_text": "",
    "expected_stderr_hex": "",
  })
  assert_eq(case_quality_kind(silent), "exact")
  assert_eq(case_quality_errors(silent), [])
  let differential = { ..silent, comparison: None, }
  assert_true(
    case_quality_errors(differential).contains(
      "independent stream assertions are not executed locally",
    ),
  )
}

///|
test "quality requires explicit finite fragment review and exact other stream" {
  let partial = quality_case({
    "expected_status": 1,
    "expected_stdout_text": "",
    "expected_stderr_contains": "permission denied",
    "diagnostic_reason": "The operating system supplies the final path wording.",
  })
  let descriptor : Json = {
    "kind": "diagnostic-fragment",
    "reason": "Status, empty stdout and the permission failure reason are exact; the host formats paths.",
  }
  assert_false(case_quality_errors(partial).is_empty())
  assert_eq(case_quality_errors(partial, descriptor~), [])
  for fragment in ["", "\n", ":"] {
    assert_false(
      case_quality_errors(
        { ..partial, expected_stderr_contains: Some(fragment), },
        descriptor~,
      ).is_empty(),
    )
  }
  assert_false(
    case_quality_errors(
      {
        ..partial,
        expected_stdout_text: None,
        expected_stdout_contains: Some("record"),
      },
      descriptor~,
    ).is_empty(),
  )
  assert_false(
    case_quality_errors(
      {
        ..partial,
        expected_rejection: Some("permission denied"),
        expected_status: 0,
      },
      descriptor~,
    ).is_empty(),
  )
}

///|
test "dynamic and scenario metadata cannot certify an unwired observer" {
  let dynamic = quality_case({
    "expected_stdout_contains": "match",
    "expected_stderr_text": "",
    "diagnostic_reason": "Variable timing fields require parsed records.",
  })
  let descriptor : Json = {
    "kind": "dynamic",
    "reason": "Parse all JSON events and compare independently fixed path, record and submatch fields.",
    "required_observers": ["parsed-json-v1"],
    "streams": ["stdout"],
  }
  assert_false(case_quality_errors(dynamic, descriptor~).is_empty())
  assert_eq(
    case_quality_errors(dynamic, descriptor~, wired_observers=["parsed-json-v1"]),
    [],
  )
  let invalid_descriptors : Array[Json] = [
    {
      "kind": "dynamic",
      "reason": "Review",
      "required_observers": [],
      "streams": ["stdout"],
    },
    {
      "kind": "dynamic",
      "reason": "Review",
      "required_observers": ["parsed-json-v1"],
      "streams": ["stderr"],
    },
    {
      "kind": "dynamic",
      "reason": "Review",
      "required_observers": ["parsed-json-v1", "parsed-json-v1"],
      "streams": ["stdout"],
    },
  ]
  for invalid in invalid_descriptors {
    assert_false(
      case_quality_errors(dynamic, descriptor=invalid, wired_observers=[
        "parsed-json-v1",
      ]).is_empty(),
    )
  }
  let scenario = { ..quality_case({}), comparison: Some("scenario"), }
  let scenario_descriptor : Json = {
    "kind": "scenario",
    "reason": "The scenario compares captured request bodies and complete file inventories to reviewed values.",
    "required_observers": ["request-body", "file-inventory"],
  }
  assert_false(
    case_quality_errors(scenario, descriptor=scenario_descriptor, wired_observers=[
      "request-body",
    ]).is_empty(),
  )
  assert_eq(
    case_quality_errors(scenario, descriptor=scenario_descriptor, wired_observers=[
      "request-body", "file-inventory",
    ]),
    [],
  )
  assert_false(
    case_quality_errors(dynamic, descriptor=scenario_descriptor, wired_observers=[
      "request-body", "file-inventory",
    ]).is_empty(),
  )
}
