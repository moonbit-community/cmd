///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test identity
test "eval identity" {
  let results = coverage_eval(".", "42")
  json_inspect(results, content=[42])
}

///|
test "eval identity with object" {
  let results = coverage_eval(".", "{\"a\": 1}")
  json_inspect(results, content=[{ "a": 1 }])
}

///|
/// Test literals
test "eval null literal" {
  let results = coverage_eval("null", "42")
  json_inspect(results, content=[null])
}

///|
test "eval number literal" {
  let results = coverage_eval("123", "{}")
  json_inspect(results, content=[123])
}

///|
test "eval string literal" {
  let results = coverage_eval("\"hello\"", "null")
  json_inspect(results, content=["hello"])
}
