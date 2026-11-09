///|
test "wget response admission folds public suffix case without rewriting the chain" {
  let jar = CookieJar::new()
  jar.load_netscape(".COM\tTRUE\t/\tFALSE\t0\tsid\told\n")
  let url = @netops.parse_absolute_url("http://com/step/0")
  jar.receive(url, [wire_cookie("sid=new; Domain=COM; Path=/").unwrap()], 100L)
  assert_eq(jar.header_for(url, 100L), Some("sid=new"))
  assert_true(jar.netscape().contains(".COM\tTRUE\t/\tFALSE\t0\tsid\tnew\n"))
  jar.receive(
    url,
    [wire_cookie("sid=ignored; Domain=COM; Path=/foreign; Max-Age=0").unwrap()],
    100L,
  )
  assert_eq(jar.header_for(url, 100L), Some("sid=new"))
}

///|
test "wget leading dot admission is separate from stored and reloaded identity" {
  let jar = CookieJar::new()
  let url = @netops.parse_absolute_url("http://a.example.com/step/0")
  jar.receive(
    url,
    [wire_cookie("sid=new; Domain=..a.example.com; Path=/").unwrap()],
    100L,
  )
  assert_eq(jar.header_for(url, 100L), None)
  let saved = jar.netscape()
  assert_true(saved.contains("..a.example.com\tTRUE\t/\tFALSE\t0\tsid\tnew\n"))
  let restored = CookieJar::new()
  restored.load_netscape(saved)
  assert_eq(restored.header_for(url, 100L), None)
  assert_true(
    restored
    .netscape()
    .contains("..a.example.com\tTRUE\t/\tFALSE\t0\tsid\tnew\n"),
  )
}

///|
test "fixed wget raw unicode hosts use byte lengths and the legacy domain heuristic" {
  for
    (host, domain, accepted) in [
      ("☃.github.io", "github.io", true),
      ("☃.cnn.de", "cnn.de", false),
      ("x.é.uk", "é.uk", false),
      ("x.☃.uk", "☃.uk", false),
      ("x.éé.uk", "éé.uk", true),
    ] {
    assert_eq(wget_cookie_domain_allows(host, domain), accepted, msg=host)
  }
  assert_false(wget_cookie_domain_allows("a.github.io", "github.io"))
  assert_true(wget_cookie_domain_allows("a.cnn.de", "cnn.de"))
  assert_false(wget_cookie_domain_allows("a.example.com", "ａ.example.com"))
}
