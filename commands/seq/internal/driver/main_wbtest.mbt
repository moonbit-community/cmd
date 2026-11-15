///|
test "seq decimal precision boundary rejects before evaluation" {
  assert_eq(parse_decimal("1e4096").render().length(), 4097)
  assert_eq(parse_decimal("1e-4096").render().length(), 4098)
  for input in ["1e4097", "1e-4097", "1".repeat(4097)] {
    try parse_decimal(input) catch {
      _ => ()
    } noraise {
      _ => fail("documented precision boundary must reject")
    }
  }
}
