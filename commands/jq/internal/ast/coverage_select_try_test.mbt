///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: select(empty) yields no outputs" {
  json_inspect(coverage_eval(".[] | select(empty)", "[1, 2, 3]"), content=[])
}

///|
test "coverage: try-catch executes catch branch" {
  json_inspect(coverage_eval("try (1 / 0) catch 42", "null"), content=[42])
}
