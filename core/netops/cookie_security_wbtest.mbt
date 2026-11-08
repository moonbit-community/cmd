///|
test "curl implicit cookie hosts preserve DNS case and canonicalize IPv6 case" {
  for
    (host, target, stored) in [
      ("MiXeD.Example.COM", "mixed.example.com", "MiXeD.Example.COM"),
      ("[2001:DB8::1]", "[2001:db8::1]", "2001:db8::1"),
    ] {
    let jar = CookieJar::new()
    jar.receive(
      parse_absolute_url("http://" + host + "/set"),
      [@http.Cookie("sid", "v", path="/")],
      100L,
      profile=CurlProfile,
    )
    assert_eq(jar.entries.length(), 1)
    assert_eq(jar.entries[0].domain, stored)
    assert_eq(
      jar.header_for(
        parse_absolute_url("http://" + target + "/"),
        101L,
        profile=CurlProfile,
      ),
      Some("sid=v"),
    )
  }
}

///|
test "curl preserves received domain spelling while matching case insensitively" {
  let jar = CookieJar::new()
  let url = parse_absolute_url("http://a.example.com/set")
  jar.receive(
    url,
    [@http.Cookie("sid", "first", domain="EXAMPLE.COM", path="/")],
    100L,
    profile=CurlProfile,
  )
  assert_true(
    jar.netscape().contains(".EXAMPLE.COM\tTRUE\t/\tFALSE\t0\tsid\tfirst\n"),
  )
  assert_eq(jar.header_for(url, 101L, profile=CurlProfile), Some("sid=first"))
  jar.receive(
    url,
    [@http.Cookie("sid", "second", domain="eXample.com", path="/")],
    102L,
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(jar.entries[0].domain, "eXample.com")
  assert_eq(jar.header_for(url, 103L, profile=CurlProfile), Some("sid=second"))
}

///|
test "curl preserves imported domain spelling without weakening secure overlays or PSL checks" {
  let jar = CookieJar::new()
  jar.load_netscape(
    ".EXAMPLE.COM\tTRUE\t/\tTRUE\t0\tsid\tsecure\n.CO.UK\tTRUE\t/\tFALSE\t0\tbad\tv\n",
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(jar.entries[0].domain, "EXAMPLE.COM")
  jar.receive(
    parse_absolute_url("http://a.example.com/set"),
    [@http.Cookie("sid", "plain", domain="example.com", path="/")],
    100L,
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(
    jar.header_for(
      parse_absolute_url("https://A.EXAMPLE.COM/"),
      101L,
      profile=CurlProfile,
    ),
    Some("sid=secure"),
  )
  assert_eq(
    jar.header_for(
      parse_absolute_url("http://A.EXAMPLE.COM/"),
      101L,
      profile=CurlProfile,
    ),
    None,
  )
}

///|
test "curl secure cookies use the pinned HTTPS and exact loopback contexts" {
  for
    (source, secure) in [
      ("https://www.example.test/set", true),
      ("http://www.example.test/set", false),
      ("http://localhost/set", true),
      ("http://LOCALHOST/set", true),
      ("http://127.0.0.1/set", true),
      ("http://[::1]/set", true),
      ("http://127.0.0.2/set", false),
      ("http://localhost./set", false),
      ("http://sub.localhost/set", false),
    ] {
    let jar = CookieJar::new()
    let url = parse_absolute_url(source)
    jar.receive(
      url,
      [@http.Cookie("sid", "secure", secure=true, path="/")],
      100L,
      profile=CurlProfile,
    )
    assert_eq(jar.entries.length(), if secure { 1 } else { 0 }, msg=source)
    assert_eq(
      jar.header_for(url, 101L, profile=CurlProfile),
      if secure {
        Some("sid=secure")
      } else {
        None
      },
      msg=source,
    )
  }
  let strict = CookieJar::new()
  strict.receive(
    parse_absolute_url("http://localhost/"),
    [@http.Cookie("sid", "secure", secure=true)],
    100L,
  )
  assert_eq(
    strict.header_for(parse_absolute_url("http://localhost/"), 101L),
    None,
  )
}

///|
test "curl cookie prefixes inspect effective security path and domain scope" {
  for
    (source, name, secure, domain, path, accepted) in [
      (
        "https://www.example.test/set",
        "__Secure-a",
        false,
        None,
        Some("/"),
        false,
      ),
      (
        "https://www.example.test/set",
        "__Secure-a",
        true,
        None,
        Some("/"),
        true,
      ),
      (
        "https://www.example.test/set",
        "__secure-a",
        false,
        None,
        Some("/"),
        true,
      ),
      ("https://www.example.test/set", "__Host-a", true, None, Some("/"), true),
      (
        "https://www.example.test/set",
        "__Host-a",
        false,
        None,
        Some("/"),
        false,
      ),
      (
        "https://www.example.test/set",
        "__Host-a",
        true,
        Some("www.example.test"),
        Some("/"),
        false,
      ),
      (
        "https://www.example.test/set",
        "__Host-a",
        true,
        None,
        Some("/private"),
        false,
      ),
      ("https://www.example.test/set", "__Host-a", true, None, None, true),
      (
        "https://www.example.test/private/set",
        "__Host-a",
        true,
        None,
        None,
        false,
      ),
      (
        "https://www.example.test/private/set",
        "__Host-a",
        true,
        None,
        Some("relative"),
        true,
      ),
      (
        "https://www.example.test/set",
        "__Host-a",
        true,
        None,
        Some("\"/\""),
        true,
      ),
      (
        "http://127.0.0.1/set",
        "__Host-a",
        true,
        Some("127.0.0.1"),
        Some("/"),
        true,
      ),
    ] {
    let jar = CookieJar::new()
    jar.receive(
      parse_absolute_url(source),
      [@http.Cookie(name, "value", secure~, domain?, path?)],
      100L,
      profile=CurlProfile,
    )
    assert_eq(
      jar.entries.length(),
      if accepted {
        1
      } else {
        0
      },
      msg=source + " " + name + " " + path.unwrap_or("default"),
    )
    if accepted && name == "__Host-a" {
      assert_true(jar.entries[0].host_only)
      assert_eq(jar.entries[0].path, "/")
    }
  }
}

///|
test "curl insecure replacements cannot overlay a live secure cookie" {
  for
    (old_path, new_path, blocked) in [
      ("/", "/other", true),
      ("/login", "/login", true),
      ("/login", "/login/en", true),
      ("/login", "/loginhelper", true),
      ("/login/en", "/login/fr", true),
      ("/login", "/other", false),
    ] {
    let jar = CookieJar::new()
    jar.receive(
      parse_absolute_url("https://www.example.test/"),
      [@http.Cookie("sid", "original", secure=true, path=old_path)],
      100L,
      profile=CurlProfile,
    )
    jar.receive(
      parse_absolute_url("http://www.example.test/"),
      [@http.Cookie("sid", "replacement", path=new_path)],
      101L,
      profile=CurlProfile,
    )
    assert_true(jar.entries.any(cookie => cookie.value == "original"))
    assert_eq(
      jar.entries.any(cookie => cookie.value == "replacement"),
      !blocked,
      msg=old_path + " -> " + new_path,
    )
  }
  let jar = CookieJar::new()
  jar.receive(
    parse_absolute_url("https://www.example.test/"),
    [@http.Cookie("sid", "original", secure=true, path="/")],
    100L,
    profile=CurlProfile,
  )
  jar.receive(
    parse_absolute_url("http://www.example.test/"),
    [@http.Cookie("sid", "", path="/", max_age=0L)],
    101L,
    profile=CurlProfile,
  )
  assert_eq(
    jar.header_for(
      parse_absolute_url("https://www.example.test/"),
      102L,
      profile=CurlProfile,
    ),
    Some("sid=original"),
  )
}

///|
test "curl host-only and domain cookies keep independent replacement identity" {
  let jar = CookieJar::new()
  let source = parse_absolute_url("https://www.example.test/")
  jar.receive(
    source,
    [
      @http.Cookie("sid", "host", path="/"),
      @http.Cookie("sid", "domain", domain="www.example.test", path="/"),
    ],
    100L,
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 2)
  jar.receive(
    source,
    [@http.Cookie("sid", "", domain="www.example.test", path="/", max_age=0L)],
    101L,
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 1)
  assert_true(jar.entries[0].host_only)
  assert_eq(jar.header_for(source, 102L, profile=CurlProfile), Some("sid=host"))
}

///|
test "curl jar imports normalize paths before validating prefixes" {
  for path in ["", "T", "TR", "TRUE", "F", "FALS", "FALSE"] {
    let jar = CookieJar::new()
    jar.load_netscape(
      "127.0.0.1\tFALSE\t" + path + "\tTRUE\t0\t__Host-a\tv\n",
      profile=CurlProfile,
    )
    assert_true(jar.entries.is_empty(), msg=path)
  }
  for
    (path, expected) in [
      ("//", "/"),
      ("\"/\"", "/"),
      ("relative", "/"),
      ("/nested/", "/nested"),
    ] {
    let jar = CookieJar::new()
    jar.load_netscape(
      "127.0.0.1\tFALSE\t" + path + "\tTRUE\t0\t__Host-a\tv\n",
      profile=CurlProfile,
    )
    assert_eq(
      jar.entries.length(),
      if expected == "/" {
        1
      } else {
        0
      },
      msg=path,
    )
    if expected == "/" {
      assert_eq(jar.entries[0].path, expected)
    }
  }
}

///|
test "curl jar prefix rejection preserves valid records and scope identity" {
  let jar = CookieJar::new()
  jar.load_netscape(
    "example.test\tFALSE\t/\tTRUE\t0\t__Host-a\tvalid\n" +
    "example.test\tFALSE\t/\tFALSE\t0\t__Host-a\tinvalid\n" +
    "example.test\tTRUE\t/\tTRUE\t0\t__Host-b\tinvalid\n" +
    "example.test\tFALSE\t/\tFALSE\t0\t__Secure-a\tinvalid\n" +
    "example.test\tFALSE\t/\tTRUE\t0\tsid\thost\n" +
    ".example.test\tTRUE\t/\tTRUE\t0\tsid\tdomain\n",
    profile=CurlProfile,
  )
  assert_eq(jar.entries.length(), 3)
  assert_true(
    jar.entries.any(cookie => {
      cookie.name == "__Host-a" && cookie.value == "valid"
    }),
  )
  assert_eq(
    jar.header_for(
      parse_absolute_url("https://example.test/"),
      100L,
      profile=CurlProfile,
    ),
    Some("__Host-a=valid; sid=domain; sid=host"),
  )
}

///|
test "wget retains its independent prefix admission and replacement policy" {
  let jar = CookieJar::new()
  let source = parse_absolute_url("http://www.example.test/")
  jar.receive(
    source,
    [
      @http.Cookie("__Host-a", "plain", path="/"),
      @http.Cookie("sid", "secure", secure=true, path="/"),
    ],
    100L,
    profile=WgetProfile,
  )
  assert_eq(jar.entries.length(), 2)
  assert_eq(
    jar.header_for(source, 101L, profile=WgetProfile),
    Some("__Host-a=plain"),
  )
  jar.receive(
    source,
    [@http.Cookie("sid", "domain", domain="www.example.test", path="/")],
    102L,
    profile=WgetProfile,
  )
  assert_eq(jar.entries.length(), 2)
  assert_eq(
    jar.header_for(source, 103L, profile=WgetProfile),
    Some("__Host-a=plain; sid=domain"),
  )
  jar.load_netscape("www.example.test\tFALSE\t/\tFALSE\t0\t__Secure-a\tjar\n")
  assert_true(jar.entries.any(cookie => cookie.name == "__Secure-a"))
}

///|
test "curl insecure overlay checks overlap expiry and secure contexts" {
  for
    (old_domain, old_expiry, source, blocked) in [
      ("example.test", None, "http://www.example.test/", true),
      ("www.example.test", None, "http://example.test/", true),
      ("1.2.3.4", None, "http://2.3.4/", true),
      ("other.test", None, "http://www.example.test/", false),
      ("example.test", Some(100L), "http://www.example.test/", false),
      ("example.test", None, "https://www.example.test/", false),
      ("localhost", None, "http://localhost/", false),
    ] {
    let jar = CookieJar::new()
    jar.entries.push({
      name: "sid",
      value: "secure",
      domain: old_domain,
      host_only: false,
      path: "/one/two",
      secure: true,
      http_only: false,
      expires: old_expiry,
    })
    jar.receive(
      parse_absolute_url(source),
      [@http.Cookie("sid", "plain", path="/oneelse")],
      101L,
      profile=CurlProfile,
    )
    assert_eq(
      jar.entries.any(cookie => cookie.value == "plain"),
      !blocked,
      msg=old_domain + " -> " + source,
    )
  }
}

///|
test "curl prefix scope uses the effective public suffix host-only conversion" {
  for domain in ["localhost", "co.uk"] {
    let jar = CookieJar::new()
    jar.receive(
      parse_absolute_url("https://" + domain + "/set"),
      [@http.Cookie("__Host-a", "v", secure=true, domain~, path="/")],
      100L,
      profile=CurlProfile,
    )
    assert_eq(jar.entries.length(), 1)
    assert_true(jar.entries[0].host_only)
  }
}

///|
test "curl cookie OWS is normalized before prefix and overlay decisions" {
  let source = parse_absolute_url("https://www.example.test/set")
  for
    field in [
      "__Host-a=bad; Secure; Path= /nested", "__Host-a=bad; Secure; Path =/nested",
      "__Host-a=bad; Secure; Path= \t\"/nested\"", "__Host-a=bad; Secure; Path\t=\t/nested",
      "__Host-a=bad; Secure; Domain = www.example.test; Path=/", "__Host-a=bad; Secure; Domain=www.example.test; Domain=; Path=/",
    ] {
    let jar = CookieJar::new()
    jar.receive(
      source,
      [wire_cookie(field, CurlProfile).unwrap()],
      100L,
      profile=CurlProfile,
    )
    assert_true(jar.entries.is_empty(), msg=field)
  }
  let jar = CookieJar::new()
  jar.receive(
    source,
    [wire_cookie(" __Host-a \t= v \t; Secure; Path = / ", CurlProfile).unwrap()],
    100L,
    profile=CurlProfile,
  )
  assert_eq(
    jar.header_for(source, 101L, profile=CurlProfile),
    Some("__Host-a=v"),
  )
  let guarded = CookieJar::new()
  guarded.receive(
    source,
    [@http.Cookie("sid", "secure", secure=true, path="/")],
    100L,
    profile=CurlProfile,
  )
  guarded.receive(
    parse_absolute_url("http://www.example.test/set"),
    [wire_cookie("sid \t= plain ; Path = /", CurlProfile).unwrap()],
    101L,
    profile=CurlProfile,
  )
  assert_eq(
    guarded.header_for(source, 102L, profile=CurlProfile),
    Some("sid=secure"),
  )
}

///|
test "curl empty attributes retain prior domain expiry and flag semantics" {
  let parsed = wire_cookie(
    "__Host-a=v; Domain= 127.0.0.1 ; Domain=; Path = / ; Max-Age= 100 ; Max-Age= ; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Expires=; Secure",
    CurlProfile,
  ).unwrap()
  assert_eq(parsed.domain, Some("127.0.0.1"))
  assert_eq(parsed.path, Some("/"))
  assert_eq(parsed.max_age, Some(100L))
  assert_eq(parsed.expires_raw, Some("Wed, 21 Oct 2015 07:28:00 GMT"))
  assert_true(parsed.secure)
  let assigned_flag = wire_cookie(
    "__Secure-a=v; Secure = true; Path=/",
    CurlProfile,
  ).unwrap()
  assert_false(assigned_flag.secure)
}
