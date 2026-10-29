///|
test "boolean count preparation is lazy and over-budget rejection is cached" {
  let regex = Regex::new("(a|b)*a[ab]{9}")
  assert_true(regex.count_plan is Uninitialized)
  let hay = b"ababababbaba\n".to_fixedarray()
  assert_eq(regex.count_boolean_lines(hay, 0, hay.length(), b'\n'), None)
  assert_true(regex.count_plan is Declined)
  assert_eq(regex.count_boolean_lines(hay, 0, hay.length(), b'\n'), None)
  assert_eq(regex.search_half(hay, 0, hay.length(), 0, hay.length()), Some(12))
}

///|
test "required literal filtering retains later candidates after a sparse tail" {
  let regex = Regex::new("[0-9]{4}.*gamma")
  let filter = Regex::new("gamma")
  let body = b"0001 gamma\n".repeat(16) +
    Bytes::make(262144, b'x') +
    b"\nxxxx gamma\n0002 gamma\n" +
    Bytes::make(4096, b'x') +
    b"\n0003 gamma"
  let hay = body.to_fixedarray()
  assert_true(regex.count_plan is Uninitialized)
  assert_eq(
    regex.count_boolean_lines(
      hay,
      0,
      hay.length(),
      b'\n',
      required=Some(filter),
    ),
    Some(18L),
  )
  assert_true(regex.count_plan is Ready(_))
  assert_eq(regex.count_boolean_lines(hay, 0, hay.length(), b'\n'), Some(18L))
}
