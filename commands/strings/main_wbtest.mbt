///|
test "strings keeps printable runs and minimum length" {
  assert_eq(records(b"xxhello\x00world\nno", 4), [(0, "xxhello"), (8, "world")])
}

///|
test "strings formats requested radix" {
  assert_eq(radix_string(10, 2), "1010")
  assert_eq(radix_string(10, 8), "12")
  assert_eq(radix_string(10, 16), "a")
  assert_eq(parse_radix("x"), Some(16))
  assert_eq(parse_radix("d"), None)
}
