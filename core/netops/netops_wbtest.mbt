///|
test "HTTP method names are case insensitive" {
  for
    (name, expected) in [
      ("GET", Get),
      ("HEAD", Head),
      ("POST", Post),
      ("PUT", Put),
      ("DELETE", Delete),
      ("CONNECT", Connect),
      ("OPTIONS", Options),
      ("TRACE", Trace),
      ("PATCH", Patch),
    ] {
    assert_eq(parse_http_method(name), expected)
    assert_eq(parse_http_method(name.to_lower()), expected)
  }
}

///|
test "RFC 3986 relative references resolve against the current response URL" {
  let base = parse_absolute_url("http://a/b/c/d;p?q")
  let cases = [
    ("g", "http://a/b/c/g"),
    ("./g", "http://a/b/c/g"),
    ("g/", "http://a/b/c/g/"),
    ("/g", "http://a/g"),
    ("//g/x", "http://g/x"),
    ("?y", "http://a/b/c/d;p?y"),
    ("g?y", "http://a/b/c/g?y"),
    ("../g", "http://a/b/g"),
    ("../../g", "http://a/g"),
  ]
  for item in cases {
    assert_eq(resolve_location(base, item.0).to_url(), item.1)
  }
}

///|
test "unsupported protocols and invalid ports fail before network access" {
  for value in ["ftp://example.test/x", "http://example.test:0/x"] {
    try parse_absolute_url(value) catch {
      TransferError(..) => ()
    } noraise {
      _ => fail("expected URL parsing to fail")
    }
  }
}
