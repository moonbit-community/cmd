///|
test "type selections retain defaults and invalid names fail during preparation" {
  for args in [["--type", "rust"], ["--type-not", "rust"]] {
    let low = LowArgs::default()
    parse_into(args, low)
    let types = types_from_low(low)
    assert_true(types.definitions().length() > 0)
  }
  let listing = LowArgs::default()
  parse_into(["--type-list"], listing)
  assert_true(types_from_low(listing).definitions().length() > 0)
  for
    args in [
      ["--type", "not-a-real-file-type"],
      ["--type-add", "invalid"],
      ["--type-clear", "rust", "--type", "rust"],
    ] {
    let low = LowArgs::default()
    parse_into(args, low)
    try types_from_low(low) catch {
      RgError(_) => ()
    } noraise {
      _ => fail("invalid file type configuration must fail before input")
    }
  }
}
