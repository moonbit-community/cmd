///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Corner case tests for splits

///|
test "corner: splits with single delimiter" {
  debug_inspect(
    test_query("[splits(\",\")]", "\"a,b,c,d\""),
    content=(
      #|"Array([String(\"a\"), String(\"b\"), String(\"c\"), String(\"d\")])"
    ),
  )
}

///|
test "corner: splits with empty result" {
  debug_inspect(
    test_query("[splits(\",\")]", "\",,,\""),
    content=(
      #|"Array([String(\"\"), String(\"\"), String(\"\"), String(\"\")])"
    ),
  )
}
