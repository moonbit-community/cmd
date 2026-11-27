///|
test "install accepts exact octal modes and rejects invalid modes" {
  assert_eq(@copy.mode("0751"), 0o751)
  assert_eq(@copy.mode("0000"), 0)
  for value in ["", "197", "10000", "u+x"] {
    try @copy.mode(value) catch {
      _ => ()
    } noraise {
      _ => fail("invalid mode accepted")
    }
  }
}
