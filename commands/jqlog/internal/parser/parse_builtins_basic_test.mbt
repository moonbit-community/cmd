///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing basic built-in functions
test "parse length" {
  json_inspect(@parser.parse("length"), content="Length")
}

///|
test "parse keys" {
  json_inspect(@parser.parse("keys"), content="Keys")
}

///|
test "parse type" {
  json_inspect(@parser.parse("type"), content="Type")
}
