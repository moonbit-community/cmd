///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Corner case tests for transpose

///|
test "corner: transpose matrix" {
  debug_inspect(
    test_query("transpose", "[[1,2,3],[4,5,6]]"),
    content=(
      #|"Array(\n  [\n    Array([Number(1), Number(4)]),\n    Array([Number(2), Number(5)]),\n    Array([Number(3), Number(6)]),\n  ],\n)"
    ),
  )
}

///|
test "corner: transpose with uneven rows" {
  debug_inspect(
    test_query("transpose", "[[1,2,3],[4,5],[6]]"),
    content=(
      #|"Array(\n  [\n    Array([Number(1), Number(4), Number(6)]),\n    Array([Number(2), Number(5)]),\n    Array([Number(3)]),\n  ],\n)"
    ),
  )
}

///|
test "corner: transpose empty matrix" {
  debug_inspect(
    test_query("transpose", "[]"),
    content=(
      #|"Array([])"
    ),
  )
}
