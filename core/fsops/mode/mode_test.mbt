///|
test "octal permission modes retain prefixes, bounds and errors" {
  for
    (text, mode) in [
      ("0", 0),
      ("0755", 0o755),
      ("0o640", 0o640),
      ("0O7777", 0o7777),
      ("000000000000007", 7),
    ] {
    assert_eq(@mode.parse_octal_mode(text), mode)
  }
  for
    (text, message) in [
      ("", "empty mode"),
      ("0o", "empty mode"),
      ("8", "invalid mode"),
      (" 7", "invalid mode"),
      ("u=rwx", "invalid mode"),
      ("10000", "mode out of range"),
      ("777777777777777777777", "mode out of range"),
    ] {
    try @mode.parse_octal_mode(text) catch {
      Failure(actual) => assert_true(actual.has_suffix("FAILED: " + message))
      _ => fail("unexpected mode error")
    } noraise {
      _ => fail("invalid mode accepted: " + text)
    }
  }
}
