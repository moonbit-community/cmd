///|
test "procps pretty uptime includes zero minutes after a full unit" {
  assert_eq(pretty(5.1), "up 0 minutes")
  assert_eq(pretty(3600.1), "up 1 hour, 0 minutes")
  assert_eq(pretty(90061.5), "up 1 day, 1 hour, 1 minute")
}
