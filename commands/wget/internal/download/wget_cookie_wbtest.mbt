///|
test "wget host cookies isolate nondefault ports and preserve any-port neighbors" {
  let jar = CookieJar::new()
  let first = @netops.parse_absolute_url("http://a.example.com:8123/step/0")
  let second = @netops.parse_absolute_url("http://a.example.com:8124/step/1")
  for (url, value) in [(first, "one"), (second, "two")] {
    jar.receive(url, [Cookie::new("sid", value, path="/")], 100L)
  }
  assert_eq(jar.header_for(first, 100L), Some("sid=one"))
  assert_eq(jar.header_for(second, 100L), Some("sid=two"))
  jar.receive(
    first,
    [Cookie::new("sid", "any", domain="a.example.com", path="/")],
    100L,
  )
  assert_eq(jar.header_for(first, 100L), Some("sid=any; sid=one"))
  jar.receive(first, [Cookie::new("sid", "", path="/", max_age=0L)], 100L)
  assert_eq(jar.header_for(first, 100L), Some("sid=any"))
  assert_eq(jar.header_for(second, 100L), Some("sid=any; sid=two"))
  let saved = jar.netscape()
  assert_true(
    saved.contains("a.example.com:8124\tFALSE\t/\tFALSE\t0\tsid\ttwo\n"),
  )
  let restored = CookieJar::new()
  restored.load_netscape(saved)
  assert_eq(restored.header_for(first, 100L), Some("sid=any"))
  assert_eq(restored.header_for(second, 100L), Some("sid=any; sid=two"))
}

///|
test "wget wire default ports are any-port while explicit jar ports remain scoped" {
  for host in ["a.example.com", "a.example.com:80", "a.example.com:443"] {
    let jar = CookieJar::new()
    jar.receive(
      @netops.parse_absolute_url("http://" + host + "/"),
      [Cookie::new("sid", "v")],
      100L,
    )
    assert_eq(
      jar.header_for(
        @netops.parse_absolute_url("http://a.example.com:8123/"),
        100L,
      ),
      Some("sid=v"),
    )
    assert_true(
      jar.netscape().contains("a.example.com\tFALSE\t/\tFALSE\t0\tsid\tv\n"),
    )
  }
  let jar = CookieJar::new()
  jar.load_netscape("a.example.com:80\tFALSE\t/\tFALSE\t0\tsid\tv\n")
  assert_eq(
    jar.header_for(@netops.parse_absolute_url("http://a.example.com/"), 100L),
    Some("sid=v"),
  )
  assert_eq(
    jar.header_for(
      @netops.parse_absolute_url("http://a.example.com:8123/"),
      100L,
    ),
    None,
  )
}

///|
test "wget jar booleans comments whitespace ports and value tabs preserve its dialect" {
  let jar = CookieJar::new()
  jar.load_netscape(
    "  #HttpOnly_a.example.com\tFALSE\t/\tFALSE\t0\thidden\tv\n" +
    " \t\r\u{000b}\u{000c}.a.example.com:0008123\ttrue\t/\ttrue\t0\tsid\tleft\tright\r\n" +
    "a.example.com:0\tFALSE\t/\tFALSE\t0\tzero\tv\n",
  )
  let first = @netops.parse_absolute_url("http://a.example.com:8123/")
  assert_eq(jar.header_for(first, 100L), Some("sid=left\tright; zero=v"))
  assert_eq(
    jar.header_for(
      @netops.parse_absolute_url("http://child.a.example.com:8123/"),
      100L,
    ),
    None,
  )
  let saved = jar.netscape()
  assert_false(saved.contains("hidden"))
  assert_true(
    saved.contains("a.example.com:8123\tFALSE\t/\tFALSE\t0\tsid\tleft\tright\n"),
  )
  assert_true(saved.contains("a.example.com\tFALSE\t/\tFALSE\t0\tzero\tv\n"))
}

///|
test "wget imported stale cookies preserve live records and domain chain spelling" {
  let jar = CookieJar::new()
  jar.load_netscape("A.Example.COM\tFALSE\t/\tFALSE\t0\tsid\told\n")
  jar.load_netscape("a.example.com\tFALSE\t/\tFALSE\t1\tsid\tstale\n")
  let url = @netops.parse_absolute_url("http://a.example.com/")
  assert_eq(jar.header_for(url, 100L), Some("sid=old"))
  jar.receive(
    url,
    [Cookie::new("sid", "new", domain="a.example.com", path="/")],
    100L,
  )
  assert_true(
    jar.netscape().contains(".A.Example.COM\tTRUE\t/\tFALSE\t0\tsid\tnew\n"),
  )
  jar.receive(url, [Cookie::new("sid", "", path="/", max_age=0L)], 100L)
  jar.receive(
    url,
    [Cookie::new("fresh", "v", domain="a.EXAMPLE.com", path="/")],
    100L,
  )
  assert_true(
    jar.netscape().contains(".a.EXAMPLE.com\tTRUE\t/\tFALSE\t0\tfresh\tv\n"),
  )
}

///|
test "wget sends identical name value pairs once across matching paths" {
  let jar = CookieJar::new()
  jar.load_netscape(
    "a.example.com\tFALSE\t/\tFALSE\t0\tsid\tv\n" +
    "a.example.com\tFALSE\t/step\tFALSE\t0\tsid\tv\n",
  )
  assert_eq(
    jar.header_for(
      @netops.parse_absolute_url("http://a.example.com/step/0"),
      100L,
    ),
    Some("sid=v"),
  )
  assert_eq(jar.entries.length(), 2)
  let distinct = CookieJar::new()
  distinct.load_netscape(
    "a.example.com\tFALSE\t/\tFALSE\t0\ta=b\tc\n" +
    "a.example.com\tFALSE\t/\tFALSE\t0\ta\tb=c\n",
  )
  assert_eq(
    distinct.header_for(
      @netops.parse_absolute_url("http://a.example.com/"),
      100L,
    ),
    Some("a=b=c; a=b=c"),
  )
}

///|
test "wget duplicate representative follows chain order before and after reload" {
  let input = "a.example.com\tFALSE\t/\tFALSE\t0\tsid\tv\n" +
    "a.example.com\tFALSE\t/st\tFALSE\t0\tother\tx\n" +
    "a.example.com\tFALSE\t/step\tFALSE\t0\tsid\tv\n"
  let jar = CookieJar::new()
  jar.load_netscape(input)
  let url = @netops.parse_absolute_url("http://a.example.com/step/0")
  assert_eq(jar.header_for(url, 100L), Some("other=x; sid=v"))
  let saved = jar.netscape()
  assert_true(
    saved.has_suffix(
      "a.example.com\tFALSE\t/step\tFALSE\t0\tsid\tv\n" +
      "a.example.com\tFALSE\t/st\tFALSE\t0\tother\tx\n" +
      "a.example.com\tFALSE\t/\tFALSE\t0\tsid\tv\n",
    ),
  )
  let reloaded = CookieJar::new()
  reloaded.load_netscape(saved)
  assert_eq(reloaded.header_for(url, 100L), Some("sid=v; other=x"))
  assert_true(reloaded.netscape().has_suffix(input))
}

///|
test "wget excludes single-label parent chains but keeps an exact single-label host" {
  for
    (domain, host, sent) in [
      ("com", "a.example.com", false),
      ("com", "com", true),
      ("localhost", "child.localhost", false),
      ("a.com", "child.a.com", true),
    ] {
    let jar = CookieJar::new()
    jar.load_netscape("." + domain + "\tTRUE\t/\tFALSE\t0\tsid\tv\n")
    assert_eq(
      jar.header_for(@netops.parse_absolute_url("http://" + host + "/"), 100L),
      if sent {
        Some("sid=v")
      } else {
        None
      },
    )
    assert_eq(jar.entries.length(), 1)
  }
}

///|
test "wget cookie host chain selection has a 32-label limit" {
  for labels in [32, 33] {
    let host = Array::make(labels, "a").join(".")
    let jar = CookieJar::new()
    jar.load_netscape(host + "\tFALSE\t/\tFALSE\t0\tsid\tv\n")
    assert_eq(
      jar.header_for(@netops.parse_absolute_url("http://" + host + "/"), 100L),
      if labels == 32 {
        Some("sid=v")
      } else {
        None
      },
    )
    assert_eq(jar.entries.length(), 1)
  }
}

///|
test "wget parses quoted parameters flags and ASCII whitespace" {
  let parsed = wire_cookie(
    "sid = \"one;two\" ; Path = \"/\"; Secure = false; HttpOnly",
  ).unwrap()
  assert_eq(parsed.name, "sid")
  assert_eq(parsed.value, "\"one;two\"")
  assert_eq(parsed.path, Some("/"))
  assert_true(parsed.secure)
  let jar = CookieJar::new()
  jar.receive(
    @netops.parse_absolute_url("https://a.example.com/"),
    [parsed],
    100L,
  )
  assert_false(jar.netscape(now=100L).contains("#HttpOnly_"))
  let extended = wire_cookie("sid*0=value; Path*=UTF-8''/; Secure*0=ignored").unwrap()
  assert_eq(extended.name, "sid")
  assert_eq(extended.path, Some("/"))
  assert_true(extended.secure)
  assert_eq(wire_cookie("sid=\"v\"junk; Path=/").unwrap().value, "\"v\"")
  for
    field in [
      "sid=\"v", "sid=v;;Path=/", "sid=v; Path", "sid=v; Expires=", "sid=v; Max-Age=-1",
    ] {
    assert_true(wire_cookie(field) is None, msg=field)
  }
}

///|
test "wget expiry deletion remains sticky across later attributes" {
  let expired = "Expires=Wed, 21 Oct 2015 07:28:00 GMT"
  let url = @netops.parse_absolute_url("https://example.com/")
  for
    attributes in [
      expired + "; Max-Age=3600",
      "Max-Age=3600; " + expired,
      "Max-Age=0; Max-Age=3600",
    ] {
    let jar = CookieJar::new()
    jar.receive(url, [Cookie::new("sid", "old", path="/")], 2000000000L)
    jar.receive(
      url,
      [wire_cookie("sid=new; Path=/; " + attributes).unwrap()],
      2000000000L,
    )
    assert_true(jar.entries.is_empty())
  }
  let ignored = wire_cookie("sid=v; Max-Age=3600; Expires=invalid").unwrap()
  let jar = CookieJar::new()
  jar.receive(url, [ignored], 2000000000L)
  assert_eq(jar.entries[0].expires, Some(2000003600L))
}
