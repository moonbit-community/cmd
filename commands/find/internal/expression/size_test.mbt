///|
test "find rounds each unit upward without overflowing file sizes" {
  assert_eq(@expression.size_units(0L, 1024UL), 0UL)
  assert_eq(@expression.size_units(1L, 1024UL), 1UL)
  assert_eq(@expression.size_units(1024L, 1024UL), 1UL)
  assert_eq(@expression.size_units(1025L, 1024UL), 2UL)
  assert_eq(@expression.size_units(4294967297L, 1073741824UL), 5UL)
  assert_eq(
    @expression.size_units(0x7fffffffffffffffL, 512UL),
    18014398509481984UL,
  )
}
