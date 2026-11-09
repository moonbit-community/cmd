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
      options(
        basic_user="user",
        basic_password="password",
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
