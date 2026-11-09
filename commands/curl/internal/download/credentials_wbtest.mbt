///|
async test "explicit Basic credential scope and redirect challenges remain independent" {
  @async.with_task_group <| group => {
    let requests : Array[(String, String?)] = []
    let basic = Some("Basic dXNlcjpwYXNz")
    let target = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => target.close())
    group.spawn_bg(no_wait=true) <| () => {
      target.run_forever() <| ((request, _, connection) => {
        let auth = request.headers.get("Authorization")
        requests.push(("target" + request.path, auth))
        if request.path == "/auth" && auth is None {
          connection
          ..send_response(401, "Unauthorized", extra_headers={
            "WWW-Authenticate": "Basic realm=\"target\"",
            "Content-Length": "0",
          })
          .end_response()
        } else {
          connection
          ..send_response(200, "OK", extra_headers={ "Content-Length": "0" })
          .end_response()
        }
      })
    }
    let origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      origin.run_forever() <| ((request, _, connection) => {
        let auth = request.headers.get("Authorization")
        requests.push(("origin" + request.path, auth))
        if request.path.has_prefix("/challenge") && auth is None {
          connection
          ..send_response(401, "Unauthorized", extra_headers={
            "WWW-Authenticate": "Basic realm=\"origin\"",
            "Content-Length": "0",
          })
          .end_response()
        } else {
          let path = if request.path == "/challenge-auth" ||
            request.path == "/restricted" {
            "/auth"
          } else {
            "/open"
          }
          connection
          ..send_response(302, "Found", extra_headers={
            "Location": "http://localhost:\{target.addr.port()}\{path}",
            "Content-Length": "0",
          })
          .end_response()
        }
      })
    }
    let base = "http://127.0.0.1:\{origin.addr.port()}"
    let restricted = transfer(
      base + "/restricted",
      DiscardOutput,
      options(
        basic_user="user",
        basic_password="pass",
        redirects=FollowRedirects(3),
      ),
    )
    assert_eq(restricted.status, 401)
    assert_eq(requests, [("origin/restricted", basic), ("target/auth", None)])
    requests.clear()
  }
}
