///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: explode/implode and type mismatches" {
  json_inspect(coverage_eval("explode", "\"A\""), content=[[65]])
  json_inspect(coverage_eval("implode", "[65]"), content=["A"])
  // Invalid code point is ignored.
  json_inspect(coverage_eval("implode", "[1114112]"), content=[""])
  assert_coverage_eval_error("explode", "1")
  assert_coverage_eval_error("implode", "\"x\"")
}
