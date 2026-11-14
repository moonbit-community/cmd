///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing if-then-else
test "parse if-then-else" {
  json_inspect(@parser.parse("if .x then .y else .z end"), content=[
    "IfThenElse",
    ["Key", "x"],
    ["Key", "y"],
    ["Key", "z"],
  ])
}

///|
/// Test parsing try-catch
test "parse try without catch" {
  json_inspect(@parser.parse("try .foo"), content=[
    "TryCatch",
    ["Key", "foo"],
    null,
  ])
}

///|
test "parse try with catch" {
  json_inspect(@parser.parse("try .foo catch .bar"), content=[
    "TryCatch",
    ["Key", "foo"],
    [["Key", "bar"]],
  ])
}

///|
/// Test parsing recurse
test "parse recurse" {
  json_inspect(@parser.parse(".."), content="Recurse")
}
