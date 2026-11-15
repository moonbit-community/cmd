///|
test "hexdump count radix and suffixes" {
  assert_eq(parse_count("0x10"), 16L)
  assert_eq(parse_count("2KiB"), 2048L)
  assert_eq(parse_count("2KB"), 2000L)
}
