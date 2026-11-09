///|
test "wget numeric expiry accepts scanf prefixes and keeps its minus one rejection" {
  for
    (text, expected) in [
      ("120.9", 120.9),
      ("+120", 120.0),
      ("1.2e3", 1200.0),
      ("0x1.ep6", 120.0),
      ("0x78", 120.0),
      ("120tail", 120.0),
      ("120,9", 120.0),
      ("120e", 120.0),
      ("120e+", 120.0),
      ("0x1p+", 1.0),
      (" \t+120.9", 120.9),
      ("-1.0000000000000001", -1.0),
      ("-1.0000000000000002", -1.0000000000000002),
      ("1e-999", 0.0),
      ("-1e-999", -0.0),
      ("5e-324", 5.0e-324),
      ("9007199254740993", 9007199254740992.0),
    ] {
    assert_eq(wget_cookie_number(text), Some(expected), msg=text)
  }
  for text in ["0x", "+", ".", "junk", "", "\u{00a0}120"] {
    assert_true(wget_cookie_number(text) is None, msg=text)
  }
  for
    text in [
      "0x.", "0X.", "+0x.", "-0x.", "0x.p", "0x.p+", "0x.p-", "0x.pfoo", "0x.g",
      "0x..", "0x.p1", "0x.p99999999999999999999999",
    ] {
    assert_eq(wget_cookie_number(text), Some(0.0), msg=text)
  }
  for text in ["NaN", "-nan", "nan(payload)", "nantail"] {
    assert_true(wget_cookie_number(text).unwrap().is_nan(), msg=text)
  }
  for text in ["inf", "-inf", "+INFINITY", "inftail", "1e309", "-1e309"] {
    assert_true(wget_cookie_number(text).unwrap().is_inf(), msg=text)
  }
}

///|
test "wget numeric expiry separates rejected deleted stale and permanent zero records" {
  let now = 2000000000L
  let url = @netops.parse_absolute_url("http://a.example.com/")
  for
    (age, value, expiry, spelling) in [
      ("-1", "old", None, "A.Example.com"),
      ("-1tail", "old", None, "A.Example.com"),
      ("-1.0000000000000001", "old", None, "A.Example.com"),
      ("-1.1", "new", Some(1999999999L), "A.Example.com"),
      ("-2", "new", Some(1999999998L), "A.Example.com"),
      ("0.1", "new", Some(now), "A.Example.com"),
      ("-0.1", "new", Some(now), "A.Example.com"),
      ("5e-324", "new", Some(now), "A.Example.com"),
      ("-5e-324", "new", Some(now), "A.Example.com"),
      ("-2000000000", "new", Some(0L), "A.Example.com"),
      ("120.9", "new", Some(2000000120L), "A.Example.com"),
      ("0", "", None, "a.eXample.com"),
      ("-0", "", None, "a.eXample.com"),
      ("0tail", "", None, "a.eXample.com"),
      ("1e-999", "", None, "a.eXample.com"),
    ] {
    let jar = CookieJar::new()
    jar.load_netscape_at(".A.Example.com\tTRUE\t/\tFALSE\t0\tsid\told\n", now)
    if wire_cookie("sid=new; Domain=a.example.com; Path=/; Max-Age=" + age)
      is Some(cookie) {
      jar.receive(url, [cookie], now)
    }
    if value == "" {
      assert_true(jar.entries.is_empty(), msg=age)
    } else {
      assert_eq(jar.entries.length(), 1, msg=age)
      assert_eq(jar.entries[0].value, value, msg=age)
      assert_eq(jar.entries[0].expires, expiry, msg=age)
      let live = expiry is None ||
        expiry == Some(0L) ||
        expiry == Some(now) ||
        expiry == Some(2000000120L)
      assert_eq(
        jar.header_for(url, now),
        if live {
          Some("sid=" + value)
        } else {
          None
        },
        msg=age,
      )
      if expiry == Some(now) {
        assert_eq(jar.header_for(url, now + 1L), None, msg=age)
        assert_eq(jar.entries.length(), 1, msg=age)
      }
    }
    jar.receive(
      url,
      [wire_cookie("other=v; Domain=a.eXample.com; Path=/").unwrap()],
      now,
    )
    assert_eq(jar.entries[0].domain, spelling, msg=age)
  }
}

///|
test "wget jar compares floating expiry before conversion and rounds saved integers" {
  let now = 2000000000L
  let url = @netops.parse_absolute_url("http://a.example.com/")
  for
    (text, value, expiry) in [
      ("4102444800.9", "new", Some(4102444800L)),
      ("0xF4865700p0", "new", Some(4102444800L)),
      ("4.1024448e9", "new", Some(4102444800L)),
      ("4102444800tail", "new", Some(4102444800L)),
      ("9007199254740993", "new", Some(9007199254740992L)),
      ("9223372036854774784", "new", Some(9223372036854774784L)),
      ("2000000000", "new", Some(now)),
      ("2000000000.9", "new", Some(now)),
      ("1999999999.9", "old", None),
      ("0tail", "new", None),
      ("nan", "new", Some(-9223372036854775808L)),
      ("inf", "new", Some(-9223372036854775808L)),
      ("9223372036854775807", "new", Some(-9223372036854775808L)),
      ("-inf", "old", None),
      ("-1.1", "old", None),
    ] {
    let jar = CookieJar::new()
    jar.load_netscape_at(
      ".A.Example.com\tTRUE\t/\tFALSE\t0\tsid\told\n.a.example.com\tTRUE\t/\tFALSE\t" +
      text +
      "\tsid\tnew\n",
      now,
    )
    assert_eq(jar.entries.length(), 1, msg=text)
    assert_eq(jar.entries[0].value, value, msg=text)
    assert_eq(jar.entries[0].expires, expiry, msg=text)
    assert_eq(
      jar.header_for(url, now),
      if expiry == Some(-9223372036854775808L) {
        None
      } else {
        Some("sid=" + value)
      },
      msg=text,
    )
  }
  assert_eq(wget_cookie_saved_time(9223372036854773759L), "9223372036854773760")
  assert_eq(wget_cookie_saved_time(9223372036854775807L), "9223372036854775808")
  let jar = CookieJar::new()
  jar.receive(
    url,
    [
      wire_cookie("sid=new; Domain=A.Example.com; Path=/; Max-Age=-2000000000").unwrap(),
    ],
    now,
  )
  let saved = jar.netscape(include_session=false, now~)
  assert_true(saved.contains(".A.Example.com\tTRUE\t/\tFALSE\t0\tsid\tnew\n"))
  let restored = CookieJar::new()
  restored.load_netscape_at(saved, now)
  assert_eq(restored.header_for(url, now), Some("sid=new"))
  assert_false(
    restored.netscape(include_session=false, now~).contains("\tsid\t"),
  )
}
