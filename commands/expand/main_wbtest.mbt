///|
fn invalid_tabs(values : Array[String]) -> String {
  try {
    ignore(parse_tabs(values))
    "accepted"
  } catch {
    TabError(message) => message
  }
}

///|
test "expand converts tabs at default and explicit stops" {
  assert_eq(expand_bytes(b"a\tb\n", false, parse_tabs([])), b"a       b\n")
  assert_eq(
    expand_bytes(b"1234\tX\t\n", false, parse_tabs(["4,10"])),
    b"1234      X \n",
  )
}

///|
test "expand initial mode preserves tabs after content" {
  assert_eq(
    expand_bytes(b"\t\tA\tB\n", true, parse_tabs([])),
    b"                A\tB\n",
  )
}

///|
test "expand absolute and relative repeating tails use distinct grids" {
  assert_eq(
    expand_bytes(b"a\tb\t\tc\n", false, parse_tabs(["4,6,/8"])),
    b"a   b   c\n",
  )
  assert_eq(
    expand_bytes(b"a\tb\t\tc\n", false, parse_tabs(["4,6,+8"])),
    b"a   b         c\n",
  )
  assert_eq(next_tab(8L, parse_tabs(["/8"])), Some(16L))
  assert_eq(next_tab(8L, parse_tabs(["+8"])), Some(16L))
}

///|
test "expand repeated tab lists accumulate and retain zero suffix semantics" {
  assert_eq(
    expand_bytes(b"a\tb\t\tc\n", false, parse_tabs(["4", "6,+8"])),
    b"a   b         c\n",
  )
  for suffix in ["4,+0", "4,/0"] {
    assert_eq(
      expand_bytes(b"a\tb\t\tc\n", false, parse_tabs([suffix])),
      b"a   b       c\n",
    )
  }
  assert_eq(next_tab(0L, parse_tabs(["2147483648"])), Some(2147483648L))
  assert_eq(
    next_tab(0L, parse_tabs(["9223372036854775807"])),
    Some(9223372036854775807L),
  )
}

///|
test "expand rejects invalid tab extensions before input" {
  assert_eq(
    invalid_tabs(["4,+8,12"]),
    "'+' specifier only allowed with the last value",
  )
  assert_eq(
    invalid_tabs(["4,/8,+4"]),
    "'/' specifier is mutually exclusive with '+'",
  )
  assert_eq(invalid_tabs(["4,4"]), "tab sizes must be ascending")
  assert_eq(invalid_tabs(["0"]), "tab size cannot be 0")
  assert_eq(
    invalid_tabs(["9223372036854775808"]),
    "tab stop is too large '9223372036854775808'",
  )
}

///|
test "expand backspace and carriage return track byte columns" {
  assert_eq(
    expand_bytes(b"abc\b\tX\r\tY\n", false, parse_tabs(["4,6,/8"])),
    b"abc\b  X\r  Y\n",
  )
  assert_eq(
    expand_bytes(b"abc\b\tX\r\tY\n", false, parse_tabs(["4,6,+8"])),
    b"abc\b  X\r        Y\n",
  )
}
