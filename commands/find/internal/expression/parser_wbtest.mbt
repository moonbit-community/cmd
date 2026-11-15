///|
test "find parses portable metadata predicates" {
  assert_true(parse_size("1c") is (Exact, 1UL, 1UL))
  assert_true(parse_size("+2k") is (Greater, 2UL, 1024UL))
  assert_true(parse_size("-3M") is (Less, 3UL, 1048576UL))
  assert_true(parse_time_number("+1") is (Greater, 1.0))
  assert_true(parse_time_number("-0") is (Less, 0.0))
}

///|
test "find size grammar retains uintmax thresholds and rejects numeric extensions" {
  assert_true(
    parse_size("18446744073709551615c") is (Exact, 0xffffffffffffffffUL, 1UL),
  )
  assert_true(parse_size("++1w") is (Greater, 1UL, 2UL))
  assert_true(parse_size("+ 1b") is (Greater, 1UL, 512UL))
  assert_true(parse_size(" 01G") is (Exact, 1UL, 1073741824UL))
  assert_true(parse_size("1K") is (Exact, 1UL, 1024UL))
  for
    text in [
      "18446744073709551616c", "1_0c", "0x1c", "+-1c", "--1c", "1.5k", "1 ",
    ] {
    let rejected = try {
      ignore(parse_size(text))
      false
    } catch {
      ParseError(_) => true
    }
    assert_true(rejected, msg=text)
  }
}

///|
test "find glob patterns remain anchored" {
  let pattern = try! glob_regex("*.mbt")
  assert_true(pattern.execute("main.mbt") is Some(_))
  assert_true(pattern.execute("main.txt") is None)
}
