///|
test "wget retains its independent prefix admission and replacement policy" {
  let jar = CookieJar::new()
  let source = @netops.parse_absolute_url("http://www.example.test/")
  jar.receive(
    source,
    [
      Cookie::new("__Host-a", "plain", path="/"),
      Cookie::new("sid", "secure", secure=true, path="/"),
    ],
    100L,
  )
  assert_eq(jar.entries.length(), 2)
  assert_eq(jar.header_for(source, 101L), Some("__Host-a=plain"))
  jar.receive(
    source,
    [Cookie::new("sid", "domain", domain="www.example.test", path="/")],
    102L,
  )
  assert_eq(jar.entries.length(), 2)
  assert_eq(jar.header_for(source, 103L), Some("__Host-a=plain; sid=domain"))
  jar.load_netscape("www.example.test\tFALSE\t/\tFALSE\t0\t__Secure-a\tjar\n")
  assert_true(jar.entries.any(cookie => cookie.name == "__Secure-a"))
}

///|
test "HTTP loopback does not send secure cookies" {
  let jar = CookieJar::new()
  let url = @netops.parse_absolute_url("http://localhost/")
  jar.receive(url, [Cookie::new("sid", "secure", secure=true)], 100L)
  assert_eq(jar.header_for(url, 101L), None)
}
