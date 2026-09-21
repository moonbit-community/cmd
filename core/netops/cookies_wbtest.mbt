///|
test "cookie matching, deletion and expiry preserve path and domain boundaries" {
  let jar = CookieJar::new()
  let source = parse_absolute_url("https://www.example.test/account/login")
  jar.receive(
    source,
    [
      @http.Cookie("host", "one"),
      @http.Cookie("domain", "two", domain=".example.test", path="/"),
      @http.Cookie("private", "three", secure=true, path="/"),
      @http.Cookie("bad", "ignored", domain="other.test"),
      @http.Cookie("short", "life", max_age=2L, path="/"),
    ],
    100L,
  )
  assert_eq(
    jar.header_for(source, 101L),
    Some("host=one; domain=two; private=three; short=life"),
  )
  assert_eq(
    jar.header_for(
      parse_absolute_url("http://www.example.test/accounting"),
      102L,
    ),
    Some("domain=two"),
  )
  assert_eq(
    jar.header_for(parse_absolute_url("https://other.example.test/"), 102L),
    Some("domain=two"),
  )
  jar.receive(
    source,
    [@http.Cookie("domain", "", domain="example.test", path="/", max_age=0L)],
    103L,
  )
  assert_eq(
    jar.header_for(parse_absolute_url("https://other.example.test/"), 103L),
    None,
  )
  jar.receive(source, [@http.Cookie("host", "replacement")], 103L)
  assert_eq(
    jar.header_for(source, 103L),
    Some("host=replacement; private=three"),
  )
  assert_false(cookie_domain_matches("127.0.0.1", "0.0.1"))
}

///|
test "cookie dates and Netscape jars round-trip persistent and session cookies" {
  assert_eq(cookie_date("Wed, 09 Jun 2021 10:18:14 GMT"), Some(1623233894L))
  assert_eq(cookie_date("Wednesday, 09-Jun-21 10:18:14 GMT"), Some(1623233894L))
  assert_eq(cookie_date("Wed Jun  9 10:18:14 2021"), Some(1623233894L))
  assert_eq(cookie_date("not a date"), None)
  let jar = CookieJar::new()
  jar.load_netscape(
    "# Netscape HTTP Cookie File\n#HttpOnly_.example.test\tTRUE\t/\tTRUE\t4102444800\ta\tone\nwww.example.test\tFALSE\t/\tFALSE\t0\tsession\ttwo\n",
  )
  let restored = CookieJar::new()
  restored.load_netscape(jar.netscape())
  let url = parse_absolute_url("https://www.example.test/")
  assert_eq(restored.header_for(url, 200L), Some("a=one; session=two"))
  let persistent = CookieJar::new()
  persistent.load_netscape(jar.netscape(include_session=false))
  assert_eq(persistent.header_for(url, 200L), Some("a=one"))
}

///|
async test "HTTP fixture challenges Basic credentials and carries redirect cookies" {
  @async.with_task_group <| group => {
    let requests : Array[(String, String?, String?)] = []
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _, connection) => {
        requests.push(
          (
            request.path,
            request.headers.get("Authorization"),
            request.headers.get("Cookie"),
          ),
        )
        if request.path == "/auth" &&
          request.headers.get("Authorization") is None {
          connection
          ..send_response(401, "Unauthorized", extra_headers={
            "WWW-Authenticate": "Basic realm=\"fixture\"",
            "Content-Length": "0",
          })
          .end_response()
        } else if request.path == "/auth" {
          connection
          ..send_response(
            302,
            "Found",
            extra_headers={ "Location": "/result", "Content-Length": "0" },
            cookies=[
              @http.Cookie("one", "1", path="/"),
              @http.Cookie("two", "2", path="/"),
            ],
          )
          .end_response()
        } else {
          connection
          ..send_response(200, "OK", extra_headers={ "Content-Length": "0" })
          .end_response()
        }
      })
    }
    let jar = CookieJar::new()
    let result = transfer(
      "http://127.0.0.1:\{server.addr.port()}/auth",
      DiscardOutput,
      transfer_options(
        basic_credentials="user:password",
        basic_preemptive=false,
        cookie_jar=jar,
        redirects=FollowRedirects(3),
      ),
    )
    assert_eq(result.status, 200)
    assert_eq(requests.length(), 3)
    assert_eq(requests[0].1, None)
    assert_eq(requests[1].1, Some("Basic dXNlcjpwYXNzd29yZA=="))
    assert_eq(requests[2].1, Some("Basic dXNlcjpwYXNzd29yZA=="))
    assert_eq(requests[2].2, Some("one=1; two=2"))
  }
}
