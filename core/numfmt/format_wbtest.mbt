///|
test "binary profiles round hexadecimal midpoint inputs to even" {
  for
    (profile, midpoint, above, expected) in [
      (
        Binary64,
        "0x1.00000000000008p0",
        "0x1.00000000000018p0",
        "0x1.0000000000002p+0",
      ),
      (
        Extended80,
        "0x1.0000000000000001p0",
        "0x1.0000000000000003p0",
        "0x1.0000000000000004p+0",
      ),
      (
        Binary128,
        "0x1." + "0".repeat(28) + "8p0",
        "0x1." + "0".repeat(27) + "18p0",
        "0x1." + "0".repeat(27) + "2p+0",
      ),
    ] {
    let one = parse_prefix("1", profile).0
    assert_eq(compare(parse_prefix(midpoint, profile).0, one), 0)
    assert_eq(
      format_magnitude(
        parse_prefix(above, profile).0,
        'a',
        None,
        false,
        profile,
      ),
      expected,
    )
  }
}

///|
test "binary64 format preserves hex ties subnormal zero and decimal precision" {
  for
    (text, conversion, precision, alternate, expected) in [
      ("1.03125", 'a', Some(1), false, "0x1.0p+0"),
      ("1.09375", 'a', Some(1), false, "0x1.2p+0"),
      ("1.5", 'a', Some(0), true, "0x2.p+0"),
      ("0x1p-1074", 'a', None, false, "0x0.0000000000001p-1022"),
      ("0.1", 'f', Some(30), false, "0.100000000000000005551115123126"),
      ("0.1", 'a', Some(20), false, "0x1.999999999999a0000000p-4"),
    ] {
    assert_eq(
      format_magnitude(
        parse_prefix(text, Binary64).0,
        conversion,
        precision,
        alternate,
        Binary64,
      ),
      expected,
    )
  }
  assert_true(parse_prefix("-0", Binary64).0.is_negative())
}

///|
test "numeric prefixes distinguish malformed overflow and exact subnormal" {
  let (one, consumed, range_error) = parse_prefix("1x", Binary64)
  assert_eq((consumed, range_error), (1, false))
  assert_eq(format_magnitude(one, 'g', None, false, Binary64), "1")
  assert_eq(parse_prefix("bad", Binary64).1, 0)
  assert_true(parse_prefix("1e9999", Binary64).0 is Infinity(false))
  assert_true(parse_prefix("1e9999", Binary64).2)
  assert_true(parse_prefix("0x1p-1074", Binary64).0 is Finite(_, _, _))
  assert_true(!parse_prefix("0x1p-1074", Binary64).2)
}

///|
test "sequence arithmetic rounds multiplication before addition" {
  let first = parse_prefix("0.1", Binary64).0
  let step = first
  let value = sequence_value(first, step, BigInt::from_int(2), Binary64)
  assert_true(compare(value, parse_prefix("0.3", Binary64).0) > 0)
  assert_eq(format_magnitude(value, 'f', Some(2), false, Binary64), "0.30")
}
