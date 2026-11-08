///|
test "response cookies cannot cross complete public suffix boundaries" {
  for profile in [CurlProfile, WgetProfile] {
    for
      (host, domain) in [
        ("shop.co.uk", "co.uk"),
        ("tenant.blogspot.com", "blogspot.com"),
        ("a.test.ck", "test.ck"),
        ("a.kawasaki.jp", "kawasaki.jp"),
        ("forgot.his.name", "his.name"),
        ("a.公司.cn", "公司.cn"),
        ("a.xn--55qx5d.cn", "xn--55qx5d.cn"),
      ] {
      let jar = CookieJar::new()
      jar.receive(
        parse_absolute_url("https://" + host + "/set"),
        [@http.Cookie("sid", "bad", domain~, path="/")],
        1000L,
        profile~,
      )
      assert_eq(jar.entries.length(), 0, msg=host + " -> " + domain)
    }
  }
}

///|
test "curl exact public suffix response becomes host-only before prefix check" {
  for host in ["localhost", "co.uk", "test.ck", "blogspot.com"] {
    let jar = CookieJar::new()
    jar.receive(
      parse_absolute_url("https://" + host + "/set"),
      [@http.Cookie("__Host-a", "v", secure=true, domain=host, path="/")],
      1000L,
      profile=CurlProfile,
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
    curl.load_netscape(row, profile=CurlProfile)
    assert_eq(curl.entries.length(), 0, msg=domain)
    let wget = CookieJar::new()
    wget.load_netscape(row, profile=WgetProfile)
    assert_eq(wget.entries.length(), 1, msg=domain)
  }
}

///|
test "rejected wget suffix deletion leaves a loaded value intact" {
  let jar = CookieJar::new()
  jar.load_netscape("co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n", profile=WgetProfile)
  jar.receive(
    parse_absolute_url("https://shop.co.uk/set"),
    [@http.Cookie("sid", "", domain="co.uk", path="/", max_age=0L)],
    1000L,
    profile=WgetProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(jar.entries[0].value, "old")
}

///|
fn suffix_test_literal(text : StringView) -> String? raise {
  let text = text.trim()
  if text == "null" {
    return None
  }
  guard text.has_prefix("'") && text.has_suffix("'") else {
    fail("invalid independent PSL corpus literal")
  }
  Some(text[1:text.length() - 1].to_owned())
}

///|
async test "complete official public suffix corpus keeps independent expectations" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @path.Path(root).dirname().to_string()
    guard parent != root else { fail("public suffix corpus workspace missing") }
    root = parent
  }
  let bytes = @fs.read_file(root + "/tests/fixtures/psl/test_psl.txt").binary()
  assert_eq(
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes)),
    "8f50ad958916d6a8f79fba2363501475571acce752757f9126fe9d2f17dd920d",
  )
  let mut count = 0
  for line in @utf8.decode(bytes).split("\n") {
    guard line.has_prefix("checkPublicSuffix(") else { continue }
    guard line.has_suffix(");") else { fail("invalid PSL corpus record") }
    let pair = line[18:line.length() - 2].split(",").to_array()
    assert_eq(pair.length(), 2)
    let host = suffix_test_literal(pair[0])
    let expected = suffix_test_literal(pair[1])
    let actual = match host {
      None => None
      Some(host) if host.has_prefix(".") => None
      Some(host) => {
        let mut domain = host.to_lower()
        let mut registrable = None
        while !cookie_public_suffix(domain) {
          match domain.find(".") {
            Some(dot) => {
              registrable = Some(domain)
              domain = domain[dot + 1:].to_owned()
            }
            None => break
          }
        }
        registrable
      }
    }
    assert_eq(actual, expected, msg=line.to_owned())
    count += 1
  }
  assert_eq(count, 78)
}

///|
test "cookie suffix lookup preserves wildcard exceptions and non-contiguous rules" {
  for
    domain in [
      "co.uk", "blogspot.com", "kawasaki.jp", "test.ck", "unknown", "公司.cn",
      "xn--55qx5d.cn",
    ] {
    assert_true(cookie_public_suffix(domain), msg=domain)
  }
  for
    domain in [
      "www.ck", "city.kawasaki.jp", "his.name", "a.unknown", "under_score.example",
    ] {
    assert_false(cookie_public_suffix(domain), msg=domain)
  }
  assert_eq(cookie_longest_suffix("a.b.forgot.his.name"), "forgot.his.name")
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
  assert_false(cookie_public_suffix("a.".repeat(255) + "com"))
  assert_false(cookie_ip_literal("::ffff:192.168.001.2"))
  assert_true(cookie_ip_literal("::ffff:192.168.1.2"))
  assert_eq(cookie_longest_suffix("a.".repeat(300) + "co.uk"), "co.uk")
}

///|
test "curl file PSL admission uses one-dot removal without rewriting other dots" {
  let jar = CookieJar::new()
  jar.load_netscape(
    ".localhost\tFALSE\t/\tFALSE\t0\tone\tv\n" +
    "..localhost\tFALSE\t/\tFALSE\t0\ttwo\tv\n" +
    "...localhost\tFALSE\t/\tFALSE\t0\tthree\tv\n" +
    "..example.com\tFALSE\t/\tFALSE\t0\tfour\tv\n",
    profile=CurlProfile,
  )
  assert_eq(jar.entries.map(cookie => (cookie.name, cookie.domain)), [
    ("one", "localhost"),
    ("three", "..localhost"),
    ("four", ".example.com"),
  ])
}

///|
test "multi-dot suffix response cannot delete a trusted wget file cookie" {
  let jar = CookieJar::new()
  jar.load_netscape("co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n", profile=WgetProfile)
  jar.receive(
    parse_absolute_url("https://x..co.uk/"),
    [@http.Cookie("sid", "", domain="..co.uk", path="/", max_age=0L)],
    1000L,
    profile=WgetProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(jar.entries[0].value, "old")
  let curl = CookieJar::new()
  curl.receive(
    parse_absolute_url("https://x..co.uk/"),
    [@http.Cookie("sid", "bad", domain="..co.uk", path="/")],
    1000L,
    profile=CurlProfile,
  )
  assert_true(curl.entries.is_empty())
}
