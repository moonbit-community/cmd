///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: iterator empty branch for .[]" {
  json_inspect(coverage_eval(".[]", "1"), content=[])
}

///|
test "coverage: object construction edge cases" {
  json_inspect(coverage_eval("{(empty): 1, \"a\": 2}", "null"), content=[])
  assert_coverage_eval_error("{(1): 2}", "null")
  json_inspect(coverage_eval("{\"a\": empty}", "null"), content=[])
  json_inspect(coverage_eval("{a}", "1"), content=[{ "a": null }])
}

///|
test "coverage: object constructor shorthand {a}" {
  json_inspect(coverage_eval("{a}", "{\"a\": 1}"), content=[{ "a": 1 }])
  json_inspect(coverage_eval("{a}", "{\"b\": 2}"), content=[{ "a": null }])
}
