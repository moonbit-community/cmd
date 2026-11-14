///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
test "range function" {
  let result = run_jq("range(5)", "null")
  debug_inspect(
    result,
    content="Ok([Number(0), Number(1), Number(2), Number(3), Number(4)])",
  )
}

///|
test "first function" {
  let result = run_jq("first", "[1,2,3]")
  debug_inspect(result, content="Ok([Number(1)])")
}

///|
test "last function" {
  let result = run_jq("last", "[1,2,3]")
  debug_inspect(result, content="Ok([Number(3)])")
}
