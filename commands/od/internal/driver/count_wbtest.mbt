///|
test "od count radix and suffixes" {
  assert_eq(parse_count("0x10"), 16L)
  assert_eq(parse_count("010"), 8L)
  assert_eq(parse_count("2K"), 2048L)
}
