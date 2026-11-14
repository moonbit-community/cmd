///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: array comparisons exercise element and length ordering" {
  json_inspect(coverage_eval("[1] < [1, 2]", "null"), content=[true])
  json_inspect(coverage_eval("[1, 0] < [1, 2]", "null"), content=[true])
}

///|
test "coverage: invalid arithmetic operations error" {
  assert_coverage_eval_error("1 + []", "null")
  assert_coverage_eval_error("1 - \"x\"", "null")
  assert_coverage_eval_error("1 * {}", "null")
  assert_coverage_eval_error("1 / []", "null")
}
