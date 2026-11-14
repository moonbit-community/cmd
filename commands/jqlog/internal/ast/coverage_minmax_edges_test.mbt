///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: min_by/max_by empty and invalid key" {
  json_inspect(coverage_eval("min_by(.)", "[]"), content=[null])
  json_inspect(coverage_eval("max_by(.)", "[]"), content=[null])
  // Key expression yields empty => null.
  json_inspect(coverage_eval("min_by(empty)", "[1, 2]"), content=[null])
  json_inspect(coverage_eval("max_by(empty)", "[1, 2]"), content=[null])
  assert_coverage_eval_error("min_by(.)", "1")
  assert_coverage_eval_error("max_by(.)", "1")
}
