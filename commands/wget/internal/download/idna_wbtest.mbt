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
test "wget renders mapped host colons and default ports without changing identity" {
  for
    (input, expected) in [
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
    assert_eq(parsed.request_host(), expected)
    let relative = @netops.resolve_location(parsed, "/next").for_transfer()
    assert_eq(relative.host, parsed.host)
    assert_eq(relative.port, parsed.port)
    assert_eq(relative.request_host(), expected)
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
test "literal and percent hosts preserve locale input distinctions" {
  assert_eq(
    @netops.parse_absolute_url("http://bücher.example/").for_transfer(
      utf8_hosts=false,
    ).host,
    "bücher.example",
  )
  assert_eq(
    @netops.parse_absolute_url("http://b%C3%BCcher.example/").for_transfer(
      utf8_hosts=false,
    ).host,
    "xn--bcher-kva.example",
  )
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
      let next = @netops.resolve_location(base, location).for_transfer()
      assert_eq(next.host, expected)
      assert_eq(next.port, Some(8080))
      assert_eq(next.user_info, Some("user:secret"))
      assert_eq(next.origin_key(), base.origin_key())
      assert_eq(next.request_target(), target)
    }
  }
}
