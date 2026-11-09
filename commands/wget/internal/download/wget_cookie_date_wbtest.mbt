///|
test "wget cookie dates preserve ordered formats and the observed calendar normalization" {
  for
    date in [
      "Sun, 29 Jan 2040 22:12:57 GMT", "Sunday, 29-Jan-40 22:12:57 GMT", "Sun Jan 29 22:12:57 2040",
      "Sun, 29-Jan-2040 22:12:57 GMT", "Mon, 29 Jan 2040 22:12:57 GMT", "sUn, 29 jAn 2040 22:12:57 GMT",
      "Sunday, 29 January 2040 22:12:57 GMT", "Sun,29Jan2040 22:12:57GMT", "Sun, 29 Jan 2040 22:12:57",
      "Sun, 29 Jan 2040 22:12:57 GMTjunk", "Sun, 29 Jan 2040 22:12:57 +0200", "Sun, 29 Jan 2040 22:12:57 -0530",
      "Sun, 29 Jan 2040 22:12:57 +1junk",
    ] {
    assert_eq(wget_cookie_date(date), Some(2211487977L), msg=date)
  }
  for
    (date, expiry) in [
      ("Sun, 9 Jan 2040 2:3:4 GMT", 2209687384L),
      ("Sun, 29 Feb 2039 00:00:00 GMT", 2182550400L),
      ("Sun, 30 Feb 2040 00:00:00 GMT", 2214172800L),
      ("Sun, 31 Apr 2040 00:00:00 GMT", 2219443200L),
      ("Sun, 29 Jan 2040 22:12:60 GMT", 2211487980L),
      ("Sun, 29 Jan 2040 22:12:61 GMT", 2211487981L),
      ("Sunday, 29-Jan-68 22:12:57 GMT", 3095100777L),
      ("Sun, 29 Jan 9999 22:12:57 GMT", 253373263977L),
      ("Thu, 01 Jan 1970 00:00:00 GMT", 0L),
      ("Wed, 31 Dec 1969 23:59:58 GMT", -2L),
      ("Sat, 01 Jan 0000 00:00:00 GMT", -62167219200L),
    ] {
    assert_eq(wget_cookie_date(date), Some(expiry), msg=date)
  }
}

///|
test "wget cookie dates reject invalid format and epoch minus one" {
  for
    date in [
      "junk Sun, 29 Jan 2040 22:12:57 GMT", "29 Jan 2040 22:12:57 GMT", "Bad, 29 Jan 2040 22:12:57 GMT",
      "Sun, 29 Januaryish 2040 22:12:57 GMT", "2040 Jan 29 22:12:57", "Sun 29 Jan 2040 22:12:57 GMT",
      "Sun, 29 Jan 2040 22:12:57 UTC", "Sun, 29 Jan 2040 22:12:57 gmt", "Sun, 29 Jan 2040 22:12:57 +",
      "Sun, 0 Jan 2040 22:12:57 GMT", "Sun, 32 Jan 2040 22:12:57 GMT", "Sun, 29 Jan 2040 24:12:57 GMT",
      "Sun, 29 Jan 2040 22:60:57 GMT", "Sun, 29 Jan 2040 22:12:62 GMT", "Sun, 29 Jan 10000 22:12:57 GMT",
      "Wed, 31 Dec 1969 23:59:59 GMT",
    ] {
    assert_eq(wget_cookie_date(date), None, msg=date)
  }
}
