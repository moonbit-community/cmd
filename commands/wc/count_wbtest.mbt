///|
test "UTF-8 counter preserves incomplete trailing sequences" {
  let first = count_utf8_chars(b"ascii\xc3", false)
  assert_eq(first, (5L, 5))
  let completed = count_utf8_chars(b"\xc3\xa9", true)
  assert_eq(completed, (1L, 2))
}

///|
test "UTF-8 counter skips malformed input" {
  assert_eq(count_utf8_chars(b"a\xffb", true), (2L, 3))
}
