///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Corner case tests for getpath

///|
test "corner: getpath returns null for non-existent path" {
  debug_inspect(
    test_query("getpath([\"x\",\"y\",\"z\"])", "{\"a\":1}"),
    content=(
      #|"Null"
    ),
  )
}

///|
test "corner: getpath with empty path returns input" {
  debug_inspect(
    test_query("getpath([])", "{\"a\":1}"),
    content=(
      #|"Object({ \"a\": Number(1) })"
    ),
  )
}
