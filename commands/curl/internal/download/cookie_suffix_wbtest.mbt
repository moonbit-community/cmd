///|
test "response cookies cannot cross complete public suffix boundaries" {
  for
    (host, domain) in [
      ("shop.co.uk", "co.uk"),
      ("tenant.blogspot.com", "blogspot.com"),
      ("a.test.ck", "test.ck"),
      ("a.kawasaki.jp", "kawasaki.jp"),
      ("forgot.his.name", "his.name"),
      ("a.xn--55qx5d.cn", "xn--55qx5d.cn"),
    ] {
    let jar = CookieJar::new()
    jar.receive(
      @netops.parse_absolute_url("https://" + host + "/set"),
      [Cookie::new("sid", "bad", domain~, path="/")],
      1000L,
    )
    assert_eq(jar.entries.length(), 0, msg=host + " -> " + domain)
  }
}

///|
test "raw unicode domain admission retains the non-NLS wget fallback" {
  let jar = CookieJar::new()
  jar.receive(
    @netops.parse_absolute_url("http://a.公司.cn/set"),
    [Cookie::new("sid", "new", domain="公司.cn", path="/")],
    1000L,
  )
  assert_eq(jar.entries.length(), 0)
}

///|
test "curl exact public suffix response becomes host-only before prefix check" {
  for host in ["localhost", "co.uk", "test.ck", "blogspot.com"] {
    let jar = CookieJar::new()
    jar.receive(
      @netops.parse_absolute_url("https://" + host + "/set"),
      [Cookie::new("__Host-a", "v", secure=true, domain=host, path="/")],
      1000L,
    )
    assert_eq(jar.entries.length(), 1, msg=host)
    assert_true(jar.entries[0].host_only)
  }
}

///|
test "curl imported suffix cookies are rejected while wget keeps file policy" {
  for domain in ["co.uk", "blogspot.com", "test.ck", "unknown", "公司.cn"] {
    let row = domain + "\tFALSE\t/\tFALSE\t0\tsid\tbad\n"
    let curl = CookieJar::new()
    curl.load_netscape(row)
    assert_eq(curl.entries.length(), 0, msg=domain)
  }
}

///|
test "wget path admission and request selection use raw prefixes and directory defaults" {
  let url = @netops.parse_absolute_url("http://shop.example.com/set")

  let jar = CookieJar::new()
  jar.load_netscape(".example.com\tTRUE\t/se\tFALSE\t0\tsid\told\n")
  assert_eq(jar.header_for(url, 1000L), None)
}

///|
test "response domain admission observes public suffix lookup" {
  assert_true(cookie_suffix_allows("a.www.ck", "www.ck"))
  assert_true(cookie_suffix_allows("a.city.kawasaki.jp", "city.kawasaki.jp"))
  assert_false(cookie_suffix_allows("a.forgot.his.name", "his.name"))
  assert_false(cookie_suffix_allows("a.b.unknown", "unknown"))
  assert_true(cookie_suffix_allows("a.b.unknown", "b.unknown"))
  assert_false(cookie_suffix_allows("x..co.uk", ".co.uk"))
  assert_false(cookie_suffix_allows("x...co.uk", "..co.uk"))
  assert_true(cookie_suffix_allows("x..example.com", ".example.com"))
}

///|
test "curl suffix admission retains trailing-dot length and file exceptions" {
  for
    domain in [
      "localhost", "localhost.", "127.0.0.1", "::1", "city.kawasaki.jp", "www.ck",
    ] {
    assert_true(curl_suffix_admission(None, domain), msg=domain)
  }
  for
    domain in [
      "co.uk.", "blogspot.com", "unknown", "a:b", "[::1]", "::0x1", "::1_2",
    ] {
    assert_false(curl_suffix_admission(None, domain), msg=domain)
  }
  assert_true(curl_suffix_admission(Some("co.uk."), "co.uk."))
  assert_false(curl_suffix_admission(Some("a.co.uk."), "co.uk."))
  assert_true(curl_suffix_admission(None, "a".repeat(250) + ".test"))
  assert_false(curl_suffix_admission(None, "a".repeat(251) + ".test"))
}

///|
test "curl file PSL admission uses one-dot removal without rewriting other dots" {
  let jar = CookieJar::new()
  jar.load_netscape(
    ".localhost\tFALSE\t/\tFALSE\t0\tone\tv\n" +
    "..localhost\tFALSE\t/\tFALSE\t0\ttwo\tv\n" +
    "...localhost\tFALSE\t/\tFALSE\t0\tthree\tv\n" +
    "..example.com\tFALSE\t/\tFALSE\t0\tfour\tv\n",
  )
  assert_eq(jar.entries.map(cookie => (cookie.name, cookie.domain)), [
    ("one", "localhost"),
    ("three", "..localhost"),
    ("four", ".example.com"),
  ])
}

///|
test "multi-dot response domain cannot enter the cookie jar" {
  let curl = CookieJar::new()
  curl.receive(
    @netops.parse_absolute_url("https://x..co.uk/"),
    [Cookie::new("sid", "bad", domain="..co.uk", path="/")],
    1000L,
  )
  assert_true(curl.entries.is_empty())
}
