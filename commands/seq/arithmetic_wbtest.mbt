///|
test "sequence arithmetic rounds multiplication before addition" {
  let first = @numfmt.parse_prefix("0.1", Binary64).0
  let step = first
  let value = sequence_value(first, step, BigInt::from_int(2), Binary64)
  assert_true(
    compare_binary(value, @numfmt.parse_prefix("0.3", Binary64).0) > 0,
  )
  assert_eq(
    @numfmt.format_magnitude(value, 'f', Some(2), false, Binary64),
    "0.30",
  )
}
