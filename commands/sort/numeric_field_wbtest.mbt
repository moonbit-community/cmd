///|
test "sort fractional field cache preserves exact conversions and raw marker collisions" {
  let keys = [
    b"", b"0", b"-0", b"-0.0", b" \t-12.345tail", b".5", b"123456789012345", b"1234567890123456",
    b"12.34567890123456789", b"1e3", b"-", b"+9.1", b"\xff12345678", b"\xff\x00\x00\x00\x00\x00\x00\xf0\x7f",
  ]
  for key in keys {
    let cached = prepare_numeric_field(key)
    assert_eq(
      numeric_field_value(cached).reinterpret_as_uint64(),
      numeric_prefix(key, false).reinterpret_as_uint64(),
    )
    for other in keys {
      assert_eq(
        numeric_field_value(cached).compare(
          numeric_field_value(prepare_numeric_field(other)),
        ),
        numeric_prefix(key, false).compare(numeric_prefix(other, false)),
      )
    }
  }
  assert_eq(prepare_numeric_field(b"123 integer"), b"123 integer")
}
