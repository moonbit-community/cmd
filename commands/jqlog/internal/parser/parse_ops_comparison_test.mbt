///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing comparison operators
test "parse equality" {
  json_inspect(@parser.parse(". == 5"), content=[
    "Operation",
    "Identity",
    "Equal",
    ["Literal", ["Number", 5]],
  ])
}

///|
test "parse inequality" {
  json_inspect(@parser.parse(". != 5"), content=[
    "Operation",
    "Identity",
    "NotEqual",
    ["Literal", ["Number", 5]],
  ])
}

///|
test "parse less than" {
  json_inspect(@parser.parse(". < 5"), content=[
    "Operation",
    "Identity",
    "LessThan",
    ["Literal", ["Number", 5]],
  ])
}

///|
test "parse greater than" {
  json_inspect(@parser.parse(". > 5"), content=[
    "Operation",
    "Identity",
    "GreaterThan",
    ["Literal", ["Number", 5]],
  ])
}
