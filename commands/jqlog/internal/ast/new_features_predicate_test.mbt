///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "any function" {
  let result = run_jq("any", "[true,false,false]")
  debug_inspect(result, content="Ok([True])")
  let result2 = run_jq("any", "[false,false]")
  debug_inspect(result2, content="Ok([False])")
}

///|
test "all function" {
  let result = run_jq("all", "[true,true,true]")
  debug_inspect(result, content="Ok([True])")
  let result2 = run_jq("all", "[true,false,true]")
  debug_inspect(result2, content="Ok([False])")
}
