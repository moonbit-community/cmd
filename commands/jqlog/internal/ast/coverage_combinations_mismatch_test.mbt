///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: combinations empty and type mismatch" {
  json_inspect(coverage_eval("combinations", "[]"), content=[])
  assert_coverage_eval_error("combinations", "1")
}
