///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: indices/index/rindex" {
  json_inspect(coverage_eval("indices(2)", "[1, 2, 1, 2]"), content=[[1, 3]])
  json_inspect(coverage_eval("index(2)", "[1, 2, 3]"), content=[1])
  json_inspect(coverage_eval("index(9)", "[1, 2, 3]"), content=[null])
  json_inspect(coverage_eval("rindex(\"o\")", "\"foobar\""), content=[2])
}
