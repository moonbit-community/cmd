///|
test "find time arguments use the finite C binary64 grammar" {
  for
    (text, wanted) in [
      (".5", 0.5),
      ("1.25", 1.25),
      ("1e1", 10.0),
      ("0x1p0", 1.0),
      (" 1", 1.0),
      ("\t1", 1.0),
      ("1e-999", 0.0),
      ("2147483648", 2147483648.0),
    ] {
    let (comparison, value) = parse_time_number(text)
    assert_true(comparison is Exact)
    assert_eq(value, wanted, msg=text)
  }
  assert_true(parse_time_number("+-1") is (Greater, -1.0))
  assert_true(parse_time_number("--1") is (Less, -1.0))
  assert_true(parse_time_number("++1") is (Greater, 1.0))
  for text in ["", "+", "1 ", "1_0", "nan", "inf", "1e999", "1e-320"] {
    let rejected = try {
      ignore(parse_time_number(text))
      false
    } catch {
      FindError(_) => true
    }
    assert_true(rejected, msg=text)
  }
}

///|
test "find day and minute windows have independent origins and open lower endpoints" {
  let now : @fsops.FileTimestamp = { seconds: 200000L, nanoseconds: 500000000, }
  let today = parse_time_test("0", now, 86400L)
  let this_minute = parse_time_test("0", now, 60L)
  let previous_minute = parse_time_test("1", now, 60L)
  for
    (seconds, nanoseconds, day, minute0, minute1) in [
      (113600L, 500000000, false, false, false),
      (113600L, 500000001, true, false, false),
      (199940L, 500000000, true, false, false),
      (199940L, 500000001, true, false, true),
      (200000L, 500000000, true, false, true),
      (200000L, 500000001, false, true, false),
      (200060L, 500000000, false, true, false),
      (200060L, 500000001, false, false, false),
    ] {
    let timestamp : @fsops.FileTimestamp = { seconds, nanoseconds, }
    assert_eq(today.matches(timestamp), day)
    assert_eq(this_minute.matches(timestamp), minute0)
    assert_eq(previous_minute.matches(timestamp), minute1)
  }
  let older_half_minute = parse_time_test("+.5", now, 60L)
  let newer_half_minute = parse_time_test("-.5", now, 60L)
  assert_false(
    older_half_minute.matches({ seconds: 199970L, nanoseconds: 500000000, }),
  )
  assert_true(
    older_half_minute.matches({ seconds: 199970L, nanoseconds: 499999999, }),
  )
  assert_false(
    newer_half_minute.matches({ seconds: 199970L, nanoseconds: 500000000, }),
  )
  assert_true(
    newer_half_minute.matches({ seconds: 199970L, nanoseconds: 500000001, }),
  )
  let newer_half_day = parse_time_test("-.5", now, 86400L)
  assert_false(
    newer_half_day.matches({ seconds: 156799L, nanoseconds: 500000000, }),
  )
  assert_true(
    newer_half_day.matches({ seconds: 156799L, nanoseconds: 500000001, }),
  )
}

///|
test "find used rejects negative age and includes zero in the first positive window" {
  let changed : @fsops.FileTimestamp = {
    seconds: 200000L,
    nanoseconds: 500000000,
  }
  for
    (seconds, nanoseconds, exact0, exact1, older_half, newer_half) in [
      (200000L, 499999999, false, false, false, false),
      (200000L, 500000000, false, true, false, true),
      (243200L, 499999999, false, true, false, true),
      (243200L, 500000000, false, true, false, false),
      (243200L, 500000001, false, true, true, false),
      (286400L, 499999999, false, true, true, false),
      (286400L, 500000000, false, false, true, false),
    ] {
    let accessed : @fsops.FileTimestamp = { seconds, nanoseconds, }
    for
      (token, expected) in [
        ("0", exact0),
        ("1", exact1),
        ("+.5", older_half),
        ("-.5", newer_half),
      ] {
      assert_eq(
        parse_time_test(token, changed, 86400L, used=true).matches_used(
          accessed, changed,
        ),
        expected,
        msg=token,
      )
    }
  }
}

///|
test "find preserves GNU negative fractional carry and rejects time conversion overflow" {
  let now : @fsops.FileTimestamp = { seconds: 200000L, nanoseconds: 900000000, }
  let query = parse_time_test("--0.005", now, 60L)
  assert_eq(query.reference.seconds, 200000L)
  assert_eq(query.reference.nanoseconds, 1200000000)
  assert_true(query.matches({ seconds: 200001L, nanoseconds: 0, }))
  for text in ["9223372036854775807", "1e300", "--1e300"] {
    let rejected = try {
      ignore(parse_time_test(text, now, 86400L))
      false
    } catch {
      FindError(_) => true
    }
    assert_true(rejected, msg=text)
  }
  assert_eq(find_seconds_difference(-9223372036854775808L, 1L), None)
  assert_eq(find_seconds_difference(9223372036854775807L, -1L), None)
}
