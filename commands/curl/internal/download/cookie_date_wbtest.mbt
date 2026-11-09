///|
test "cookie dates retain RFC token parsing and reject invalid calendar days" {
  assert_eq(cookie_date("29 Jan 2040 22:12:57 GMT"), Some(2211487977L))
  assert_eq(cookie_date("Sun, 29 Feb 2039 00:00:00 GMT"), None)
}
