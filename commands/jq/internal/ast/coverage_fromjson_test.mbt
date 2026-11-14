///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: fromjson parses and errors" {
  json_inspect(coverage_eval("fromjson", "\"{\\\"a\\\": 1}\""), content=[
    { "a": 1 },
  ])
  assert_coverage_eval_error("fromjson", "\"{\"")
  assert_coverage_eval_error("fromjson", "1")
}
