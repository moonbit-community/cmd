///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: numeric builtins type mismatches" {
  assert_coverage_eval_error("floor", "\"x\"")
  assert_coverage_eval_error("sqrt", "\"x\"")
}

///|
test "coverage: add rejects mixed number and string elements" {
  assert_coverage_eval_error("add", "[1, \"x\", 2]")
  json_inspect(coverage_eval("add", "[null, 1, null, 2]"), content=[3])
}
