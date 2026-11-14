///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing field access
test "parse field access" {
  json_inspect(@parser.parse(".foo"), content=["Key", "foo"])
}

///|
test "parse nested field access" {
  json_inspect(@parser.parse(".foo.bar"), content=[
    "Pipe",
    ["Key", "foo"],
    ["Key", "bar"],
  ])
}
