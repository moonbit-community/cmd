///|
test "tab stops distinguish periodic aligned and relative continuation" {
  for
    (values, column, expected) in (
      [
        ([], 0L, Some(8L)),
        ([], 8L, Some(16L)),
        (["4"], 4L, Some(8L)),
        (["4", "10"], 4L, Some(10L)),
        (["4", "10"], 10L, None),
        (["4,10,/8"], 10L, Some(16L)),
        (["4,10,+8"], 10L, Some(18L)),
        (["4,10,/8"], 25L, Some(32L)),
        (["4,10,+8"], 25L, Some(26L)),
        (["+4"], 5L, Some(8L)),
      ] : Array[(Array[String], Int64, Int64?)]) {
    assert_eq(@tabstops.next(column, @tabstops.parse(values)), expected)
  }
}

///|
test "tab stop validation preserves diagnostics and overflow rejection" {
  for
    (value, message) in [
      ("0", "tab size cannot be 0"),
      ("4,4", "tab sizes must be ascending"),
      ("4,+8,/8", "'/' specifier is mutually exclusive with '+'"),
      ("4x", "tab size contains invalid character(s): 'x'"),
      ("9223372036854775808", "tab stop is too large '9223372036854775808'"),
    ] {
    try @tabstops.parse([value]) catch {
      @tabstops.TabError(actual) => assert_eq(actual, message)
    } noraise {
      _ => fail("invalid tab stops must fail")
    }
  }
  for values in [[], ["4,8"], ["4,+8"]] {
    try @tabstops.next(9223372036854775807L, @tabstops.parse(values)) catch {
      @tabstops.TabError(message) =>
        assert_eq(message, "input line is too long")
    } noraise {
      _ => fail("column overflow must fail")
    }
  }
}
