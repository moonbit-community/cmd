///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: repeat with limit and empty inner" {
  json_inspect(coverage_eval("limit(5; repeat(1))", "null"), content=[
    1, 1, 1, 1, 1,
  ])
  json_inspect(coverage_eval("limit(5; repeat(empty))", "null"), content=[])
}
