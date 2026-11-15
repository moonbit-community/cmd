///|
test "sort fractional field cache preserves exact decimal ordering and raw marker collisions" {
  let ordered = [
    b"-9007199254740993", b"-9007199254740992", b"-1.000000000000000002", b"-1.000000000000000001",
    b"-.00000000000000000001", b"0", b".00000000000000000001", b"1.000000000000000001",
    b"1.000000000000000002", b"9007199254740992", b"9007199254740993",
  ]
  for i, left in ordered {
    for j, right in ordered {
      let expected = i.compare(j)
      assert_eq(compare(left, right).compare(0), expected)
      assert_eq(
        numeric_field_value(encode(left))
        .compare(numeric_field_value(encode(right)))
        .compare(0),
        expected,
      )
    }
  }
  for
    zero in [
      b"", b"-0.000", b"+9.1", b"-", b"\xff12345678", b"\xff\x00\x00\x00\x00\x00\x00\xf0\x7f",
    ] {
    assert_eq(compare(zero, b"0"), 0)
    assert_eq(encode(zero), encode(b"0"))
  }
  for
    (left, right) in [
      (b"  -0012.34000tail", b"-12.34"),
      (b".5", b"00.500"),
      (b"1e3", b"1"),
      (b"2.", b"2"),
    ] {
    assert_eq(compare(left, right), 0)
    assert_eq(encode(left), encode(right))
  }
  let large = @utf8.encode("9".repeat(4096))
  let larger = @utf8.encode("1" + "0".repeat(4096))
  assert_true(compare(large, larger) < 0)
}

///|
test "sort integral prefix accepts only exactly represented integer prefixes" {
  for
    (key, expected) in [
      (b"  -00123suffix", -123.0),
      (b"1e3", 1.0),
      (b"+7", 0.0),
      (b"--8", 0.0),
      (b"999999999999999tail", 999999999999999.0),
      (b"-", 0.0),
      (b" \xff", 0.0),
    ] {
    assert_eq(integral_prefix(key), Some(expected))
  }
  assert_true(integral_prefix(b"0.5") is None)
  assert_true(integral_prefix(b"1000000000000000") is None)
  assert_true(integral_prefix(b"9007199254740993") is None)
  assert_true(integral_prefix(b"-9007199254740993") is None)
}
