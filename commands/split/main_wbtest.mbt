///|
test "split counts complete records while preserving partial and binary records" {
  assert_eq(boundaries(b"a\nb\nc", 2, true), [(0, 4), (4, 5)])
  assert_eq(boundaries(b"\x00\xff\na", 2, false), [(0, 2), (2, 4)])
  assert_eq(boundaries(b"", 1000, true), [])
  assert_eq(byte_count("2K"), 2048)
  assert_eq(byte_count("2kB"), 2000)
}

///|
test "split expands default suffixes and exhausts explicit widths" {
  let letters = [24, 25]
  assert_true(advance_suffix(letters, 26, true))
  assert_eq(suffix_name(letters, false), "zaaa")
  let numbers = [8, 9]
  assert_true(advance_suffix(numbers, 10, true))
  assert_eq(suffix_name(numbers, true), "9000")
  assert_true(!advance_suffix([25, 25], 26, false))
}
