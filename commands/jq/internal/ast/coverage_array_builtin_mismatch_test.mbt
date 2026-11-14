///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: array builtins type mismatches" {
  assert_coverage_eval_error("sort", "1")
  assert_coverage_eval_error("reverse", "1")
  assert_coverage_eval_error("unique", "1")
  assert_coverage_eval_error("min", "1")
  assert_coverage_eval_error("max", "1")
}
