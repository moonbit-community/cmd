///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Comprehensive edge case tests

///|
test "edge: empty array operations" {
  debug_inspect(
    test_query(".[] | . * 2", "[]"),
    content=(
      #|""
    ),
  )
}

///|
test "edge: null handling" {
  debug_inspect(
    test_query(".x // \"default\"", "null"),
    content=(
      #|"String(\"default\")"
    ),
  )
}

///|
test "edge: deeply nested access" {
  debug_inspect(
    test_query(".a.b.c.d.e", "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":42}}}}}"),
    content=(
      #|"Number(42)"
    ),
  )
}

///|
test "edge: array bounds" {
  debug_inspect(
    test_query(".[100] // \"out of bounds\"", "[1,2,3]"),
    content=(
      #|"String(\"out of bounds\")"
    ),
  )
}

///|
test "edge: type mixing" {
  debug_inspect(
    test_query("type", "null"),
    content=(
      #|"String(\"null\")"
    ),
  )
}
