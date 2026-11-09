///|
test "invalid UTF-8 percent hosts reject at the URL boundary for both s" {
  for host in ["a%FF.example", "a%C3%28.example", "a%ED%A0%80.example"] {
    try
      @netops.parse_absolute_url("http://" + host + "/").for_transfer()
    catch {
      @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
    } noraise {
      _ => fail("invalid UTF-8 must not reach connection setup")
    }
  }
}

///|
test "mapped brackets cannot acquire the native loopback cookie exception" {
  let url = @netops.parse_absolute_url("http://［127.0.0.1］/set").for_transfer()
  assert_false(url.ip_literal)
  assert_eq(url.host, "[127.0.0.1]")
  assert_eq(url.cookie_host(), "[127.0.0.1]")
  assert_false(cookie_secure_context(url))
  let jar = CookieJar::new()
  jar.load_netscape(
    "127.0.0.1\tFALSE\t/\tTRUE\t0\tplain_secure\tone\n[127.0.0.1]\tFALSE\t/\tFALSE\t0\tbracket_plain\ttwo\n",
  )
  assert_eq(jar.header_for(url, 1000L), Some("bracket_plain=two"))
  jar.receive(
    url,
    [
      Cookie::new("new_plain", "value", path="/"),
      Cookie::new("__Secure-new", "value", path="/", secure=true),
    ],
    1000L,
  )
  assert_eq(
    jar.header_for(url, 1000L),
    Some("bracket_plain=two; new_plain=value"),
  )
  assert_false(jar.entries.any(cookie => cookie.name == "__Secure-new"))
  assert_true(
    jar.entries.any(cookie => {
      cookie.name == "new_plain" && cookie.domain == "[127.0.0.1]"
    }),
  )
  let native = @netops.parse_absolute_url("http://[::1]/").for_transfer()
  assert_true(native.ip_literal)
  assert_eq(native.cookie_host(), "::1")
  assert_true(cookie_secure_context(native))
  for
    (input, host) in [
      ("［localhost］", "[localhost]"),
      ("［：：１］", "[::1]"),
    ] {
    let mapped = @netops.parse_absolute_url("http://" + input + "/").for_transfer()
    assert_false(mapped.ip_literal)
    assert_eq(mapped.cookie_host(), host)
    assert_false(cookie_secure_context(mapped))
  }
}

///|
test "mapped host authority remains the curl request Host value" {
  for
    (input, _) in [
      ("http://foo：80.bü.example/start", "[foo:80.xn--b-eha.example]"),
      (
        "http://foo：80.bü.example:8123/start", "[foo:80.xn--b-eha.example]:8123",
      ),
      ("http://[::1]:80/start", "[::1]"),
      ("https://[::1]:443/start", "[::1]"),
      ("http://example.com:80/start", "example.com"),
      ("http://example.com:443/start", "example.com:443"),
    ] {
    let parsed = @netops.parse_absolute_url(input).for_transfer()
    let relative = @netops.resolve_location(parsed, "/next").for_transfer(
      redirect=true,
    )
    assert_eq(relative.host, parsed.host)
    assert_eq(relative.port, parsed.port)
    assert_eq(parsed.request_host(), parsed.endpoint)
  }
}

///|
test "international URL hosts use one canonical origin before credentials and cookies" {
  for
    (input, host) in [
      ("bücher.example", "xn--bcher-kva.example"),
      ("bu\u0308cher.example", "xn--bcher-kva.example"),
      ("faß.example", "xn--fa-hia.example"),
      ("ＢＯＯＫ。example", "book.example"),
      ("a..bücher.example", "a..xn--bcher-kva.example"),
      ("bücher.example.", "xn--bcher-kva.example."),
    ] {
    let parsed = @netops.parse_absolute_url(
      "https://user:secret@" + input + ":8443/p?q=x",
    ).for_transfer()
    assert_eq(parsed.host, host)
    assert_eq(parsed.endpoint, host + ":8443")
    assert_eq(parsed.authority, "user:secret@" + host + ":8443")
    assert_eq(parsed.origin_key(), "https://" + host + ":8443")
    assert_eq(parsed.user_info, Some("user:secret"))
    assert_eq(parsed.request_target(), "/p?q=x")
  }
}

///|
test "IDNA retries the entire host after nontransitional validation fails" {
  for
    (input, host) in [
      ("😀.faß.example", "xn--e28h.fass.example"),
      ("a\u200Db.faß.example", "ab.fass.example"),
      ("aא.faß.example", "xn--a-0hc.fass.example"),
      ("1.א.faß.example", "1.xn--4db.xn--fa-hia.example"),
    ] {
    assert_eq(
      @netops.parse_absolute_url("http://" + input + "/").for_transfer().host,
      host,
    )
  }
}

///|
test "Curl rejects invalid international hosts and preserves its ASCII bypass" {
  for
    host in [
      "\u0308bad.example", "xn--.bücher.example", "xn--abc-.bücher.example", "xn---abc.bücher.example",
      "\u1C89.example",
    ] {
    try
      @netops.parse_absolute_url("http://" + host + "/").for_transfer()
    catch {
      @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
    } noraise {
      _ => fail("invalid IDNA host must fail before connection")
    }
  }
  assert_eq(
    @netops.parse_absolute_url("http://xn--.example/").for_transfer().host,
    "xn--.example",
  )
}

///|
test "percent hosts and proxy exclusions use the selected canonical identity" {
  for input in ["bücher.example", "b%C3%BCcher.example"] {
    let url = "http://" + input + "/"
    assert_eq(
      @netops.parse_absolute_url(url).for_transfer().host,
      "xn--bcher-kva.example",
    )
    assert_true(proxy_bypassed(url, Some("xn--bcher-kva.example")))
    assert_false(proxy_bypassed(url, Some("bücher.example")))
    try @netops.parse_absolute_url(url).for_transfer(utf8_hosts=false) catch {
      @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
    } noraise {
      _ => fail("C host input cannot be decoded as UTF-8")
    }
  }
  for
    input in ["a%2fbü.example", "a%00.example", "a%0d.example", "a%FF.example"] {
    try
      @netops.parse_absolute_url("http://" + input + "/").for_transfer()
    catch {
      @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
    } noraise {
      _ => fail("invalid raw host accepted: " + input)
    }
  }
}

///|
test "relative redirects preserve mapped host delimiters as structured fields" {
  for
    (input, expected) in [
      ("℀.faß.example", "a/c.xn--fa-hia.example"),
      ("foo＠bar.example", "foo@bar.example"),
      ("foo：80.bü.example", "foo:80.xn--b-eha.example"),
    ] {
    let base = @netops.parse_absolute_url(
      "http://user:secret@" + input + ":8080/a?q=1",
    ).for_transfer()
    for
      (location, target) in [
        ("/next", "/next"),
        ("../next?q=2", "/next?q=2"),
        ("?q=3", "/a?q=3"),
      ] {
      let next = @netops.resolve_location(base, location).for_transfer(
        redirect=true,
      )
      assert_eq(next.host, expected)
      assert_eq(next.port, Some(8080))
      assert_eq(next.user_info, Some("user:secret"))
      assert_eq(next.origin_key(), base.origin_key())
      assert_eq(next.request_target(), target)
    }
  }
}
