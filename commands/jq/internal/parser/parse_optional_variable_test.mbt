///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing optional operator
test "parse optional" {
  json_inspect(@parser.parse(".foo?"), content=["Optional", ["Key", "foo"]])
}

///|
/// Test parsing variables
test "parse variable" {
  json_inspect(@parser.parse("$foo"), content=["Variable", "foo"])
}
