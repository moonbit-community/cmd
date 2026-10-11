///|
test "POSIX offsets, fractional-hour zones and future DST" {
  let winter = 2524653296L // 2050-01-01 12:34:56 UTC
  let summer = 2540289600L // 2050-07-01 12:00:00 UTC
  for
    (text, instant, seconds, name) in [
      ("UTC0", 0L, 0, "UTC"),
      ("GMT0", 0L, 0, "GMT"),
      ("<+0545>-5:45", 0L, 20700, "+0545"),
      ("EST5EDT,M3.2.0,M11.1.0", winter, -18000, "EST"),
      ("EST5EDT,M3.2.0,M11.1.0", summer, -14400, "EDT"),
      ("AEST-10AEDT,M10.1.0,M4.1.0/3", winter, 39600, "AEDT"),
      ("AEST-10AEDT,M10.1.0,M4.1.0/3", summer, 36000, "AEST"),
    ] {
    let zone = from_rules(parse_rules(text))
    assert_eq(zone.at_unix(instant).offset().seconds(), seconds)
    assert_eq(zone.abbreviation(instant), name)
  }
}

///|
test "timezone local conversion rejects DST gaps and ambiguous folds" {
  let zone = from_rules(parse_rules("EST5EDT,M3.2.0,M11.1.0"))
  for text in ["2026-03-08T02:30:00", "2026-11-01T01:30:00"] {
    let plain : @time.PlainDateTime = @string.from_str(text)
    try zone.at_local(plain) catch {
      _ => ()
    } noraise {
      _ => fail("invalid or ambiguous local time must be explicit")
    }
  }
}

///|
test "malformed timezone data raises without out-of-bounds indexing" {
  for n in 0..<100 {
    let data = Bytes::from_array(Array::make(n, 0xff))
    try decode(data) catch {
      _ => ()
    } noraise {
      _ => fail("invalid TZif was accepted")
    }
  }
  for
    text in [
      "UTC", "A0", "ABC25", "ABC1:60", "EST5EDT", "EST5EDT,M13.2.0,M11.1.0", "EST5EDT,J0,J365",
      "ABC0garbage",
    ] {
    try parse_rules(text) catch {
      _ => ()
    } noraise {
      _ => fail("invalid POSIX TZ was accepted")
    }
  }
}

///|
fn fixture_header(times : Byte, types : Byte, chars : Byte) -> Bytes {
  let bytes = Array::make(44, b'\x00')
  for i, byte in b"TZif2" {
    bytes[i] = byte
  }
  bytes[35] = times
  bytes[39] = types
  bytes[43] = chars
  Bytes::from_array(bytes)
}

///|
test "TZif selects 64-bit transitions and rejects truncated blocks" {
  // The compatibility block intentionally differs. The 64-bit transition is
  // 2147483648 (2038-01-19); it changes UTC to an offset of one hour.
  let compatibility = fixture_header(0, 1, 4) +
    b"\x00\x00\x00\x00\x00\x00OLD\x00"
  let modern = fixture_header(1, 2, 8) +
    b"\x00\x00\x00\x00\x80\x00\x00\x00\x01" +
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x0e\x10\x00\x04UTC\x00NEW\x00\n\n"
  let data = compatibility + modern
  let zone = decode(data)
  assert_eq(zone.abbreviation(2147483647L), "UTC")
  assert_eq(zone.at_unix(2147483647L).offset().seconds(), 0)
  assert_eq(zone.abbreviation(2147483648L), "NEW")
  assert_eq(zone.at_unix(2147483648L).offset().seconds(), 3600)
  for n in 0..<data.length() {
    try decode(data[:n].to_owned()) catch {
      _ => ()
    } noraise {
      _ => fail("truncated TZif accepted at \{n}")
    }
  }
}
