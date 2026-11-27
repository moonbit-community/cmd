///|
test "truncated or invalid extended entries fail before offset rewriting" {
  for
    invalid in [
      b"\x1a", b"\x1a\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x02\x00\x0c\x00",
    ] {
    try decode(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("accepted truncated terminal data")
    }
  }
}
