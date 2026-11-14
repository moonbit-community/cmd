///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: setpath out-of-range pads the array with nulls" {
  json_inspect(coverage_eval("setpath([3]; 1)", "[0]"), content=[
    [0, null, null, 1],
  ])
  json_inspect(coverage_eval("setpath([-1]; 1)", "[0, 5]"), content=[[0, 1]])
  assert_coverage_eval_error("setpath([-3]; 1)", "[0, 5]")
  assert_coverage_eval_error("setpath([1e300]; 1)", "[0]")
}
