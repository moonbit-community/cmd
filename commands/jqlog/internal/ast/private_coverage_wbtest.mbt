///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "wb: set_at_path empty path" {
  let value = Json::number(3.0)
  let result = set_at_path(null, [], value)
  json_inspect(result, content=3)
}
