///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing pipe operator
test "parse pipe" {
  json_inspect(@parser.parse(". | .foo"), content=[
    "Pipe",
    "Identity",
    ["Key", "foo"],
  ])
}

///|
test "parse chained pipes" {
  json_inspect(@parser.parse(".a | .b | .c"), content=[
    "Pipe",
    ["Pipe", ["Key", "a"], ["Key", "b"]],
    ["Key", "c"],
  ])
}

///|
/// Test parsing comma operator
test "parse comma" {
  json_inspect(@parser.parse(".a, .b"), content=[
    "Comma",
    ["Key", "a"],
    ["Key", "b"],
  ])
}
