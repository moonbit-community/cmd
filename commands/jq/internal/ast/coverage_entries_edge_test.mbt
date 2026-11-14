///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: from_entries edge cases" {
  let input = "[{\"key\":\"a\"},{\"key\":1},{\"key\":{}},{\"value\":1},1]"
  json_inspect(coverage_eval("from_entries", input), content=[
    Json::empty_object(),
  ])
  assert_coverage_eval_error("from_entries", "1")
  assert_coverage_eval_error("with_entries(.)", "1")
}
