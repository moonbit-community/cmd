///|
fn invalid_tabs(values : Array[String]) -> String {
  try {
    ignore(@tabstops.parse(values))
    "accepted"
  } catch {
    @tabstops.TabError(message) => message
  }
}

///|
test "unexpand converts leading and all blanks" {
  assert_eq(
    unexpand_bytes(b"        x\n", false, false, @tabstops.parse([])),
    b"\tx\n",
  )
  assert_eq(
    unexpand_bytes(b"x        y\n", true, false, @tabstops.parse([])),
    b"x\t y\n",
  )
}

///|
test "unexpand first-only and explicit stops" {
  assert_eq(
    unexpand_bytes(b"        x        y\n", true, true, @tabstops.parse([])),
    b"\tx        y\n",
  )
  assert_eq(
    unexpand_bytes(b"          x\n", true, false, @tabstops.parse(["4,10"])),
    b"\t\tx\n",
  )
}

///|
test "unexpand absolute and relative tails preserve blank columns" {
  assert_eq(
    unexpand_bytes(
      b"        a        b\n",
      true,
      false,
      @tabstops.parse(["4,6,/8"]),
    ),
    b"\t\t\ta\t b\n",
  )
  assert_eq(
    unexpand_bytes(
      b"        a        b\n",
      true,
      false,
      @tabstops.parse(["4,6,+8"]),
    ),
    b"\t\t  a\t   b\n",
  )
  assert_eq(
    unexpand_bytes(
      b"        a        b\n",
      true,
      false,
      @tabstops.parse(["4,8"]),
    ),
    b"\t\ta        b\n",
  )
}

///|
test "unexpand first-only overrides explicit and implicit all" {
  assert_eq(
    unexpand_bytes(
      b"        a        b\n",
      true,
      true,
      @tabstops.parse(["4,+8"]),
    ),
    b"\t    a        b\n",
  )
  assert_eq(
    unexpand_bytes(
      b"        a        b\n",
      true,
      false,
      @tabstops.parse(["4,+8"]),
    ),
    b"\t    a\t     b\n",
  )
}

///|
test "unexpand pending blanks preserve isolated spaces and existing tabs" {
  assert_eq(
    unexpand_bytes(b"1234567 x\n", true, false, @tabstops.parse([])),
    b"1234567 x\n",
  )
  assert_eq(
    unexpand_bytes(b"1234567  x\n", true, false, @tabstops.parse([])),
    b"1234567\t x\n",
  )
  assert_eq(
    unexpand_bytes(b"abc\b\tX\r\tY\n", true, false, @tabstops.parse(["4,6,+8"])),
    b"abc\b\tX\r\tY\n",
  )
}

///|
test "unexpand tab parser accumulates lists and rejects conflicting suffixes" {
  assert_eq(@tabstops.next(6L, @tabstops.parse(["4", "6,+8"])), Some(14L))
  assert_eq(@tabstops.next(4L, @tabstops.parse(["4,+0"])), Some(8L))
  assert_eq(@tabstops.next(4L, @tabstops.parse(["4,/0"])), Some(8L))
  assert_eq(
    @tabstops.next(0L, @tabstops.parse(["2147483648"])),
    Some(2147483648L),
  )
  assert_eq(
    invalid_tabs(["4,+8", "6,+8"]),
    "'+' specifier only allowed with the last value",
  )
  assert_eq(
    invalid_tabs(["4,/8,+4"]),
    "'/' specifier is mutually exclusive with '+'",
  )
  assert_eq(
    invalid_tabs(["9223372036854775808"]),
    "tab stop is too large '9223372036854775808'",
  )
  let overflow = try {
    ignore(
      unexpand_bytes(
        b"\tX",
        true,
        false,
        @tabstops.parse(["9223372036854775807"]),
      ),
    )
    "accepted"
  } catch {
    @tabstops.TabError(message) => message
  }
  assert_eq(overflow, "input line is too long")
}
