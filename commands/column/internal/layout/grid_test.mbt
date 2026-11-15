///|
test "column grid arithmetic crosses 2 GiB and 4 GiB" {
  assert_eq(@layout.grid_shape(4294967297L, 1, 16), (8L, 2L, 2147483649L))
  assert_eq(
    @layout.grid_shape(1L, 2147483646, 2147483647),
    (2147483648L, 1L, 1L),
  )
}
