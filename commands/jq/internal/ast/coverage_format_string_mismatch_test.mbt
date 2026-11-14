///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: format errors" {
  assert_coverage_eval_error("@base64", "1")
  assert_coverage_eval_error("@base64d", "1")
  assert_coverage_eval_error("@csv", "1")
  assert_coverage_eval_error("@html", "1")
  assert_coverage_eval_error("@wat", "\"x\"")
}

///|
test "coverage: string builtins mismatches" {
  assert_coverage_eval_error("startswith(\"a\")", "1")
  assert_coverage_eval_error("endswith(\"a\")", "1")
  assert_coverage_eval_error("split(\",\")", "1")
  assert_coverage_eval_error("join(\",\")", "1")
  json_inspect(coverage_eval("join(\",\")", "[1, \"a\"]"), content=["1,a"])
  json_inspect(coverage_eval("contains(empty)", "\"abc\""), content=[])
  assert_coverage_eval_error("ltrimstr(\"a\")", "1")
  assert_coverage_eval_error("rtrimstr(\"a\")", "1")
  assert_coverage_eval_error("ascii_upcase", "1")
  assert_coverage_eval_error("ascii_downcase", "1")
}
