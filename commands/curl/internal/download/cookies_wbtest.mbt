///|
fn assert_cookie_members(actual : String?, expected : String?) -> Unit raise {
  fn members(header : String?) -> Array[String]? {
    match header {
      None => None
      Some(value) => {
        let pairs = value.split("; ").map(v => v.to_owned()).collect()
        pairs.sort()
        Some(pairs)
      }
    }
  }
  // Selection and expiry are independent of ordering, checked by the wire cases.
  assert_eq(members(actual), members(expected))
} ///|

///|
test "cookie matching, deletion and expiry preserve path and domain boundaries" {
  let jar = CookieJar::new()
  let source = @netops.parse_absolute_url(
    "https://www.example.test/account/login",
  )
  jar.receive(
    source,
    [
      Cookie::new("host", "one"),
      Cookie::new("domain", "two", domain=".example.test", path="/"),
      Cookie::new("private", "three", secure=true, path="/"),
      Cookie::new("bad", "ignored", domain="other.test"),
      Cookie::new("short", "life", max_age=2L, path="/"),
    ],
    100L,
  )
  assert_cookie_members(
    jar.header_for(source, 101L),
    Some("host=one; domain=two; private=three; short=life"),
  )
  assert_cookie_members(
    jar.header_for(
      @netops.parse_absolute_url("http://www.example.test/accounting"),
      102L,
    ),
    Some("domain=two"),
  )
  assert_cookie_members(
    jar.header_for(
      @netops.parse_absolute_url("https://other.example.test/"),
      102L,
    ),
    Some("domain=two"),
  )
  jar.receive(
    source,
    [Cookie::new("domain", "", domain="example.test", path="/", max_age=0L)],
    103L,
  )
  assert_cookie_members(
    jar.header_for(
      @netops.parse_absolute_url("https://other.example.test/"),
      103L,
    ),
    None,
  )
  jar.receive(source, [Cookie::new("host", "replacement")], 103L)
  assert_cookie_members(
    jar.header_for(source, 103L),
    Some("host=replacement; private=three"),
  )
  assert_false(cookie_domain_matches("127.0.0.1", "0.0.1"))
}

///|
test "cookie dates and Netscape jars round-trip persistent and session cookies" {
  assert_eq(cookie_date("Wed, 09 Jun 2021 10:18:14 GMT"), Some(1623233894L))
  assert_eq(cookie_date("Wednesday, 09-Jun-21 10:18:14 GMT"), Some(1623233894L))
  assert_eq(cookie_date("Wed Jun  9 10:18:14 2021"), Some(1623233894L))
  assert_eq(cookie_date("not a date"), None)
  let jar = CookieJar::new()
  jar.load_netscape(
    "# Netscape HTTP Cookie File\n#HttpOnly_.example.test\tTRUE\t/\tTRUE\t4102444800\ta\tone\nwww.example.test\tFALSE\t/\tFALSE\t0\tsession\ttwo\n",
  )
  let restored = CookieJar::new()
  restored.load_netscape(jar.netscape())
  let url = @netops.parse_absolute_url("https://www.example.test/")
  assert_cookie_members(
    restored.header_for(url, 200L),
    Some("a=one; session=two"),
  )
  let persistent = CookieJar::new()
  persistent.load_netscape(jar.netscape(include_session=false))
  assert_cookie_members(persistent.header_for(url, 200L), Some("a=one"))
}
