///|
test "find parses portable metadata predicates" {
  assert_true(parse_size("1c") is (Exact, 1L, false))
  assert_true(parse_size("+2k") is (Greater, 2048L, false))
  assert_true(parse_size("-3M") is (Less, 3145728L, false))
  assert_true(parse_mtime("+1") is (Greater, 1))
  assert_true(parse_mtime("-0") is (Less, 0))
}

///|
test "find glob patterns remain anchored" {
  let pattern = try! glob_regex("*.mbt")
  assert_true(pattern.execute("main.mbt") is Some(_))
  assert_true(pattern.execute("main.txt") is None)
}
