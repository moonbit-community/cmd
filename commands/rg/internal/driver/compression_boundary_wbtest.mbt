///|
async test "decompress gzip (native)" {
  // The original optional compression smoke is now a mandatory rejection contract.
  for args in [["-z"], ["--search-zip"], ["-zz"]] {
    let low = LowArgs::default()
    parse_into(args, low)
    let rejected = try {
      ignore(HiArgs::from_low_args(low))
      false
    } catch {
      RgError(message) =>
        message == "compressed search (-z/--search-zip) is deferred in cli/rg"
      _ => false
    }
    assert_true(rejected)
  }
}
