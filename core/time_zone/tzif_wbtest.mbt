///|
fn tzif_integer(value : Int64, width : Int32) -> Bytes {
  Bytes::from_array(
    Array::makei(width, i => ((value >> ((width - i - 1) * 8)) & 255L).to_byte()),
  )
}

///|
fn tzif_fixture(
  types : Array[(Int32, Bool, String)],
  transitions : Array[(Int64, Int32)],
  footer~ : String = "",
  version~ : Byte = b'2',
) -> Bytes {
  let names = Buffer()
  let records = Buffer()
  for (offset, dst, name) in types {
    records.write_bytes(tzif_integer(offset.to_int64(), 4))
    records.write_byte(if dst { b'\x01' } else { b'\x00' })
    records.write_byte(names.length().to_byte())
    names.write_bytes(@utf8.encode(name))
    names.write_byte(b'\x00')
  }
  let header = fixture_header(
    transitions.length().to_byte(),
    types.length().to_byte(),
    names.length().to_byte(),
  ).to_array()
  header[4] = version
  let output = Buffer()
  if version != b'\x00' {
    let first = fixture_header(0, 1, 4).to_array()
    first[4] = version
    output.write_bytes(Bytes::from_array(first))
    output.write_bytes(b"\x00\x00\x00\x00\x00\x00UTC\x00")
  }
  output.write_bytes(Bytes::from_array(header))
  for (instant, _) in transitions {
    output.write_bytes(
      tzif_integer(instant, if version == b'\x00' { 4 } else { 8 }),
    )
  }
  for (_, index) in transitions {
    output.write_byte(index.to_byte())
  }
  output.write_bytes(records.to_bytes())
  output.write_bytes(names.to_bytes())
  if version != b'\x00' {
    output.write_bytes(@utf8.encode("\n" + footer + "\n"))
  }
  output.to_bytes()
}

///|
fn timestamp(text : String) -> Int64 raise {
  let plain : @time.PlainDateTime = @string.from_str(text)
  plain.to_unix_second()
}

///|
test "public TZif conversion preserves versions, zero abbreviations and fractional offsets" {
  for version in [b'\x00', b'2', b'3', b'4'] {
    for (seconds, name) in [(0, "GMT"), (20700, "NPT"), (-12600, "NST")] {
      let zone = decode(tzif_fixture([(seconds, false, name)], [], version~))
      assert_true(zone.implementation is Tzif(_))
      for instant in [0L, 2147483648L, 2540289600L] {
        let value = zone.at_unix(instant, nanosecond=123456789)
        assert_eq(value.offset().seconds(), seconds)
        assert_eq(value.nanosecond(), 123456789)
        assert_eq(zone.abbreviation(instant), name)
        assert_eq(
          zone.at_local(value.to_plain_date_time()).to_unix_second(),
          instant,
        )
      }
    }
  }
}

///|
test "public TZif history rejects local gaps and folds with unchanged diagnostics" {
  let spring = timestamp("2026-03-08T07:00:00")
  let autumn = timestamp("2026-11-01T06:00:00")
  let zone = decode(
    tzif_fixture([(-18000, false, "EST"), (-14400, true, "EDT")], [
      (spring, 1),
      (autumn, 0),
    ]),
  )
  assert_true(zone.implementation is Tzif(_))
  for
    (instant, seconds, name) in [
      (spring - 1L, -18000, "EST"),
      (spring, -14400, "EDT"),
      (autumn - 1L, -14400, "EDT"),
      (autumn, -18000, "EST"),
    ] {
    assert_eq(zone.at_unix(instant).offset().seconds(), seconds)
    assert_eq(zone.abbreviation(instant), name)
  }
  for
    (text, message) in [
      ("2026-03-08T02:30:00", "invalid local time in timezone"),
      ("2026-11-01T01:30:00", "ambiguous local time; use @SECONDS"),
    ] {
    let plain : @time.PlainDateTime = @string.from_str(text)
    try zone.at_local(plain) catch {
      Failure::Failure(actual) =>
        assert_true(actual.has_suffix(message), msg=actual)
      error => fail("unexpected local-time error: " + error.to_string())
    } noraise {
      _ => fail("gap/fold accepted: " + text)
    }
  }
}

///|
test "public TZif footer conversion preserves northern and southern future seasons" {
  let winter = timestamp("2400-01-01T12:34:56")
  let summer = timestamp("2400-07-01T12:34:56")
  for
    (rule, types, winter_offset, winter_name, summer_offset, summer_name) in [
      (
        "EST5EDT,M3.2.0,M11.1.0",
        [(-18000, false, "EST"), (-14400, true, "EDT")],
        -18000,
        "EST",
        -14400,
        "EDT",
      ),
      (
        "AEST-10AEDT,M10.1.0,M4.1.0/3",
        [(36000, false, "AEST"), (39600, true, "AEDT")],
        39600,
        "AEDT",
        36000,
        "AEST",
      ),
    ] {
    let zone = decode(tzif_fixture(types, [], footer=rule))
    assert_true(zone.implementation is Tzif(_))
    for
      (instant, offset, name) in [
        (winter, winter_offset, winter_name),
        (summer, summer_offset, summer_name),
      ] {
      assert_eq(zone.at_unix(instant).offset().seconds(), offset)
      assert_eq(zone.abbreviation(instant), name)
      assert_eq(
        zone
        .at_local(zone.at_unix(instant).to_plain_date_time())
        .to_unix_second(),
        instant,
      )
    }
  }
}

///|
test "legacy TZif designation, footer and deferred offset boundaries remain accepted" {
  let nonstandard = decode(tzif_fixture([(3600, false, "A B")], []))
  assert_true(nonstandard.implementation is Compatible(_))
  assert_eq(nonstandard.abbreviation(0L), "A B")
  assert_eq(nonstandard.at_unix(0L).offset().seconds(), 3600)
  // Existing acceptance switches to a disagreeing footer strictly after the
  // last transition. x/time rejects this file instead of changing that meaning.
  let mismatch = decode(
    tzif_fixture([(0, false, "GMT")], [(0L, 0)], footer="ABC-1"),
  )
  assert_true(mismatch.implementation is Compatible(_))
  assert_eq(mismatch.abbreviation(0L), "GMT")
  assert_eq(mismatch.abbreviation(1L), "ABC")
  assert_eq(mismatch.at_unix(1L).offset().seconds(), 3600)
  // An unused unsupported offset used to fail only when selected, not at load.
  let wide = decode(
    tzif_fixture([(0, false, "GMT"), (68400, false, "WIDE")], [(100L, 1)]),
  )
  assert_true(wide.implementation is Compatible(_))
  assert_eq(wide.at_unix(0L).offset().seconds(), 0)
  try wide.at_unix(100L) catch {
    _ => ()
  } noraise {
    _ => fail("unrepresentable offset accepted")
  }
  for rule in ["EST5EDT,J60,J300", "EST5EDT,M3.2.0/-2,M11.1.0/26"] {
    let zone = decode(tzif_fixture([(-18000, false, "EST")], [], footer=rule))
    assert_true(zone.implementation is Compatible(_))
    assert_eq(
      zone.at_unix(timestamp("2050-07-01T12:00:00")).offset().seconds(),
      -14400,
    )
  }
}

///|
test "TZif leap records and malformed indicators retain the rejection boundary" {
  let data = tzif_fixture([(0, false, "GMT")], [])
  for (index, value) in [(31, b'\x01'), (20, b'\x01'), (24, b'\x01')] {
    let changed = data.to_array()
    changed[index] = value
    try decode(Bytes::from_array(changed)) catch {
      _ => ()
    } noraise {
      _ => fail("invalid TZif accepted")
    }
  }
  for length in 0..<data.length() {
    try decode(data[:length].to_owned()) catch {
      _ => ()
    } noraise {
      _ => fail("truncated TZif accepted")
    }
  }
}
