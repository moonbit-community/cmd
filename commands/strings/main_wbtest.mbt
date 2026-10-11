///|
test "strings keeps printable runs and minimum length" {
  assert_eq(records(b"xxhello\x00world\nno", 4), [
    (0, b"xxhello"),
    (8, b"world"),
  ])
  assert_eq(records(b"ab\tcd\x00\xffabcd", 4), [(0, b"ab\tcd"), (7, b"abcd")])
  assert_eq(records(b"ab\xffcd\x00", 4, eight_bit=true), [(0, b"ab\xffcd")])
}

///|
test "strings formats requested radix" {
  assert_eq(radix_string(10, 2), "1010")
  assert_eq(radix_string(10, 8), "12")
  assert_eq(radix_string(10, 16), "a")
  assert_eq(parse_radix("x"), Some(16))
  assert_eq(parse_radix("d"), Some(10))
  assert_eq(parse_radix("b"), None)
}
