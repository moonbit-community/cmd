///|
test "exact regex counts are optional and do not replace assertions or empty matches" {
  let hay = b"alpha alpha\nbeta\nmiss".to_fixedarray()
  assert_eq(
    @regex.Regex::new("alpha|beta").count_exact_lines(
      hay,
      0,
      hay.length(),
      b'\n',
    ),
    Some(2),
  )
  for pattern in ["", "^alpha", "a.*b"] {
    assert_eq(
      @regex.Regex::new(pattern).count_exact_lines(hay, 0, hay.length(), b'\n'),
      None,
    )
  }
}
