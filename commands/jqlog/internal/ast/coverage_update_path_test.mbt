///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "coverage: update path navigates through arrays" {
  let input : String =
    #|{
    #|  "a": [1]
    #|}
  json_inspect(coverage_eval(".a[0] |= . + 1", input), content=[{ "a": [2] }])
}
