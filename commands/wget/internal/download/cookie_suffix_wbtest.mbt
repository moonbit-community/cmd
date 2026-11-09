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
  assert_eq(jar.entries.length(), 1)
}

///|
test "curl imported suffix cookies are rejected while wget keeps file policy" {
  for domain in ["co.uk", "blogspot.com", "test.ck", "unknown", "公司.cn"] {
    let row = domain + "\tFALSE\t/\tFALSE\t0\tsid\tbad\n"
    let wget = CookieJar::new()
    wget.load_netscape(row)
    assert_eq(wget.entries.length(), 1, msg=domain)
  }
}

///|
test "rejected wget suffix update discards a matching loaded value" {
  let jar = CookieJar::new()
  jar.load_netscape("co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n")
  jar.receive(
    @netops.parse_absolute_url("https://shop.co.uk/set"),
    [Cookie::new("sid", "", domain="co.uk", path="/", max_age=0L)],
    1000L,
  )
  assert_eq(jar.entries.length(), 0)
}

///|
test "wget domain rejection discards only the matching key after path validation" {
  for domain in ["co.uk", "blogspot.com", "victim.example"] {
    for age in [None, Some(0L), Some(3600L)] {
      for (path, expected) in [("/", 0), ("/blocked", 1)] {
        let jar = CookieJar::new()
        jar.load_netscape(
          domain +
          "\tTRUE\t" +
          path +
          "\tFALSE\t0\tsid\told\n" +
          domain +
          "\tTRUE\t" +
          path +
          "\tFALSE\t0\tother\tkeep\n",
        )
        jar.receive(
          @netops.parse_absolute_url("https://shop.co.uk/set"),
          [Cookie::new("sid", "new", domain~, path~, max_age?=age)],
          1000L,
        )
        assert_eq(
          jar.entries.filter(cookie => cookie.name == "sid").length(),
          expected,
          msg=domain + " " + path,
        )
        assert_eq(
          jar.entries.filter(cookie => cookie.name == "other").length(),
          1,
        )
      }
    }
  }
}

///|
test "empty wget Domain and Path reject the cookie before replacement or deletion" {
  for
    field in [
      "sid=new; Domain=co.uk; Path=", "sid=new; Domain=co.uk; Path=/; Path=", "sid=new; Domain=; Path=/",
      "sid=new; Domain=co.uk; Domain=; Path=/",
    ] {
    assert_true(wire_cookie(field) is None, msg=field)
  }
  for
    cookie in [
      Cookie::new("sid", "new", domain="co.uk", path="", max_age=0L),
      Cookie::new("sid", "new", domain="", path="/", max_age=0L),
    ] {
    let jar = CookieJar::new()
    jar.load_netscape("co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n")
    jar.receive(
      @netops.parse_absolute_url("https://shop.co.uk/set"),
      [cookie],
      1000L,
    )
    assert_eq(jar.entries.length(), 1)
    assert_eq(jar.entries[0].value, "old")
  }
}

///|
test "wget path admission and request selection use raw prefixes and directory defaults" {
  let url = @netops.parse_absolute_url("http://shop.example.com/set")

  let jar = CookieJar::new()
  jar.load_netscape(".example.com\tTRUE\t/se\tFALSE\t0\tsid\told\n")
  assert_eq(jar.header_for(url, 1000L), Some("sid=old"))

  let jar = CookieJar::new()
  jar.receive(
    @netops.parse_absolute_url("http://shop.example.com/dir/set"),
    [Cookie::new("sid", "new")],
    1000L,
  )
  assert_eq(jar.entries[0].path, "/dir/")
  assert_eq(
    jar.header_for(
      @netops.parse_absolute_url("http://shop.example.com/directory"),
      1000L,
    ),
    None,
  )
  assert_eq(
    jar.header_for(
      @netops.parse_absolute_url("http://shop.example.com/dir/next"),
      1000L,
    ),
    Some("sid=new"),
  )
}

///|
test "multi-dot suffix response cannot delete a trusted wget file cookie" {
  let jar = CookieJar::new()
  jar.load_netscape("co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n")
  jar.receive(
    @netops.parse_absolute_url("https://x..co.uk/"),
    [Cookie::new("sid", "", domain="..co.uk", path="/", max_age=0L)],
    1000L,
  )
  assert_eq(jar.entries.length(), 1)
  assert_eq(jar.entries[0].value, "old")
}
