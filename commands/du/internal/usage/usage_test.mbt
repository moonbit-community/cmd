///|
test "apparent block counts round without signed addition overflow" {
  assert_eq(@usage.blocks(0L, 1024L), 0L)
  assert_eq(@usage.blocks(1L, 1024L), 1L)
  assert_eq(@usage.blocks(1024L, 1024L), 1L)
  assert_eq(@usage.blocks(9223372036854775807L, 2L), 4611686018427387904L)
}
