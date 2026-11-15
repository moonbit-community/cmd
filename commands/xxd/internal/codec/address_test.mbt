///|
test "xxd addressed dumps preserve holes" {
  assert_eq(decoded(b"00000002: 4142  ;AB\n", @codec.Normal, 16), [
    (2L, b'A'),
    (3L, b'B'),
  ])
}
