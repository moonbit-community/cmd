///|
test "count parser accepts documented signed and scaled forms" {
  assert_true(parse_count("10") is First(10L))
  assert_true(parse_count("-2") is AllButLast(2L))
  assert_true(parse_count("+3") is First(3L))
  assert_true(parse_count("2K") is First(2048L))
  assert_true(parse_count("2KiB") is First(2048L))
  assert_true(parse_count("2KB") is First(2000L))
}

///|
test "legacy count normalization does not rewrite option values" {
  assert_eq(legacy_count_args(["-2", "file"]), ["-n", "2", "file"])
  assert_eq(legacy_count_args(["-2kq", "file"]), ["-c", "2K", "-q", "file"])
  assert_eq(legacy_count_args(["-n", "-2"]), ["-n", "-2"])
  assert_eq(legacy_count_args(["file", "-2"]), ["file", "-2"])
}
