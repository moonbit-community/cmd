///|
fn coverage_case() -> TestCase {
  {
    name: "coverage/required",
    regex: "a",
    haystack: b"a",
    matches: [[Some((0, 1))]],
    compiles: true,
    anchored: false,
    case_insensitive: false,
    unicode: true,
    utf8: true,
    match_limit: None,
    bounds: None,
    line_terminator: None,
  }
}

///|
test "corpus compile outcomes cannot become silent exclusions" {
  let valid = coverage_case()
  assert_eq(exclusion(valid), None)
  assert_eq(compile_expectation(valid, parsed=true), None)
  assert_eq(
    compile_expectation(valid, parsed=false),
    Some("coverage/required: unexpectedly failed to parse a"),
  )
  let invalid = { ..valid, regex: "(", compiles: false, }
  assert_eq(exclusion(invalid), None)
  assert_eq(compile_expectation(invalid, parsed=false), None)
  assert_eq(
    compile_expectation(invalid, parsed=true),
    Some("coverage/required: unexpectedly parsed invalid pattern ("),
  )
}

///|
test "corpus exclusions are explicit dialect and engine boundaries" {
  let valid = coverage_case()
  assert_eq(
    exclusion({ ..valid, name: "regex-lite/required", }),
    Some("regex-lite dialect"),
  )
  assert_eq(
    exclusion({ ..valid, line_terminator: Some(0), }),
    Some("custom line terminator"),
  )
  assert_eq(exclusion({ ..valid, anchored: true, }), None)
  assert_eq(
    exclusion({ ..valid, anchored: true, }, meta=true),
    Some("anchored meta search"),
  )
}

///|
async test "corpus inventory fixes exact per-engine execution obligations" {
  let cases = load()
  for
    (meta, expected_exclusions, expected_matches) in [
      (false, 20, 726),
      (true, 47, 699),
    ] {
    let excluded = cases.filter(tc => exclusion(tc, meta~) is Some(_))
    let required = cases.filter(tc => exclusion(tc, meta~) is None)
    assert_eq(excluded.length(), expected_exclusions)
    assert_eq(required.filter(tc => tc.compiles).length(), expected_matches)
    assert_eq(required.filter(tc => !tc.compiles).length(), 5)
    assert_eq(excluded.length() + required.length(), 751)
  }
}
