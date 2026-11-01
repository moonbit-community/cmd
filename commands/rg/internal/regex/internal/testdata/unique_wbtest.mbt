///|
fn group_case(name : String) -> TestCase {
  {
    name,
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
test "corpus groups retain every name for an identical execution" {
  let groups = execution_groups([group_case("first"), group_case("second")])
  assert_eq(groups.length(), 1)
  assert_eq(groups[0].fixture.name, "first")
  assert_eq(groups[0].names, ["first", "second"])
  assert_eq(alias_count(groups), 1)
  let dialect = execution_groups([
    group_case("regex-lite/first"),
    group_case("regex-lite/second"),
  ])
  assert_eq(dialect.length(), 1)
  assert_eq(exclusion(dialect[0].fixture), Some("regex-lite dialect"))
}

///|
test "corpus groups preserve flags bounds bytes captures and dialect" {
  let base = group_case("first")
  let changed = group_case("second")
  let variants : Array[TestCase] = [
    { ..changed, regex: "(?:a)", },
    { ..changed, haystack: b"a\x00", },
    { ..changed, matches: [[None]], },
    { ..changed, matches: [[Some((0, 0))]], },
    { ..changed, matches: [[Some((0, 1)), None]], },
    { ..changed, compiles: false, },
    { ..changed, anchored: true, },
    { ..changed, case_insensitive: true, },
    { ..changed, unicode: false, },
    { ..changed, utf8: false, },
    { ..changed, match_limit: Some(0), },
    { ..changed, bounds: Some((0, 1)), },
    { ..changed, line_terminator: Some(0), },
    { ..changed, name: "regex-lite/second", },
  ]
  for variant in variants {
    let groups = execution_groups([base, variant])
    assert_eq(groups.length(), 2)
    assert_eq(alias_count(groups), 0)
  }
  let absent = { ..base, matches: [[Some((0, 1)), None]], }
  let empty = { ..changed, matches: [[Some((0, 1)), Some((0, 0))]], }
  assert_eq(execution_groups([absent, empty]).length(), 2)
}

///|
test "corpus grouping cannot silently accept missing or repeated names" {
  for cases in [[group_case("")], [group_case("same"), group_case("same")]] {
    let rejected = try {
      ignore(execution_groups(cases))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "unique corpus execution and original name obligations are exact" {
  let cases = load()
  let groups = execution_groups(cases)
  assert_eq(cases.length(), 751)
  assert_eq(groups.length(), 726)
  assert_eq(alias_count(groups), 25)
  let names : Set[String] = Set([])
  for group in groups {
    assert_eq(group.fixture.name, group.names[0])
    for name in group.names {
      assert_false(names.contains(name))
      names.add(name)
    }
  }
  assert_eq(names.length(), 751)
  for tc in cases {
    assert_true(names.contains(tc.name))
  }
  for
    (
      meta,
      unique_matches,
      unique_exclusions,
      original_matches,
      original_exclusions,
    ) in [(false, 701, 20, 726, 20), (true, 675, 46, 699, 47)] {
    let mut matches = 0
    let mut rejected = 0
    let mut excluded = 0
    let mut represented_matches = 0
    let mut represented_rejected = 0
    let mut represented_excluded = 0
    for group in groups {
      if exclusion(group.fixture, meta~) is Some(_) {
        excluded += 1
        represented_excluded += group.names.length()
      } else if group.fixture.compiles {
        matches += 1
        represented_matches += group.names.length()
      } else {
        rejected += 1
        represented_rejected += group.names.length()
      }
    }
    assert_eq(matches, unique_matches)
    assert_eq(rejected, 5)
    assert_eq(excluded, unique_exclusions)
    assert_eq(represented_matches, original_matches)
    assert_eq(represented_rejected, 5)
    assert_eq(represented_excluded, original_exclusions)
  }
}
