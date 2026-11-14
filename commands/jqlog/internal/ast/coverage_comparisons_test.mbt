///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: null/bool comparisons" {
  json_inspect(coverage_eval("null < null", "null"), content=[false])
  json_inspect(coverage_eval("null < false", "null"), content=[true])
  json_inspect(coverage_eval("false < true", "null"), content=[true])
  json_inspect(coverage_eval("true > false", "null"), content=[true])
}
