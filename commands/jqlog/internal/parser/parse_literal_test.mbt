///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing literals
test "parse null literal" {
  let expr = @parser.parse("null")
  json_inspect(expr, content=["Literal", "Null"])
}

///|
test "parse boolean literals" {
  json_inspect(@parser.parse("true"), content=["Literal", ["Bool", true]])
  json_inspect(@parser.parse("false"), content=["Literal", ["Bool", false]])
}

///|
test "parse number literals" {
  json_inspect(@parser.parse("42"), content=["Literal", ["Number", 42]])
  json_inspect(@parser.parse("3.14"), content=["Literal", ["Number", 3.14]])
}

///|
test "parse string literal" {
  json_inspect(@parser.parse("\"hello\""), content=[
    "Literal",
    ["String", "hello"],
  ])
}
