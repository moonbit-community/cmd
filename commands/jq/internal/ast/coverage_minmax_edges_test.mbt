///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: min_by/max_by empty and invalid key" {
  json_inspect(coverage_eval("min_by(.)", "[]"), content=[null])
  json_inspect(coverage_eval("max_by(.)", "[]"), content=[null])
  // Empty key streams compare equally; min keeps the first and max the last.
  json_inspect(coverage_eval("min_by(empty)", "[1, 2]"), content=[1])
  json_inspect(coverage_eval("max_by(empty)", "[1, 2]"), content=[2])
  assert_coverage_eval_error("min_by(.)", "1")
  assert_coverage_eval_error("max_by(.)", "1")
}
