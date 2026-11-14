///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test parsing identity
test "parse identity" {
  let expr = @parser.parse(".")
  json_inspect(expr, content="Identity")
}
