///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing assignment operators
test "parse update" {
  json_inspect(@parser.parse(".foo |= . + 1"), content=[
    "Update",
    ["Key", "foo"],
    ["Operation", "Identity", "Add", ["Literal", ["Number", 1]]],
  ])
}

///|
test "parse alternative" {
  json_inspect(@parser.parse(".foo // .bar"), content=[
    "Alternative",
    ["Key", "foo"],
    ["Key", "bar"],
  ])
}
