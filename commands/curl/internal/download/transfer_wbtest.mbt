///|
async fn serve_test_requests(
  group : @async.TaskGroup[Unit],
) -> (@http.Server, Int32) {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
  group.spawn_bg(no_wait=true) <| () => {
    server.run_forever() <| ((request, _body, connection) => {
      match request.path {
        "/fixed" => {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "5",
          })
          if request.meth == @http.Head {
            connection.end_response()
          } else {
            connection..write("hello").end_response()
          }
        }
        "/chunked" => {
          connection.send_response(200, "OK")
          connection..write("slow-").flush()
          @async.sleep(5)
          connection..write("stream").end_response()
        }
        "/redirect-a" =>
          connection
          ..send_response(302, "Found", extra_headers={
            "Location": "nested/../redirect-b?from=a",
            "Content-Length": "0",
          })
          .end_response()
        "/redirect-b?from=a" => {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "5",
          })
          connection..write("final").end_response()
        }
        "/redirect-loop" =>
          connection
          ..send_response(302, "Found", extra_headers={
            "Location": "/redirect-loop",
            "Content-Length": "0",
          })
          .end_response()
        "/redirect-invalid" =>
          connection
          ..send_response(302, "Found", extra_headers={
            "Location": "ftp://example.test/file",
            "Content-Length": "0",
          })
          .end_response()
        "/echo" => {
          let content = _body.read_all().binary()
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": content.length().to_string(),
          })
          connection..write(content).end_response()
        }
        "/range" => {
          let ranged = request.headers.get("Range") == Some("bytes=3-")
          let content = if ranged { "lo" } else { "hello" }
          let headers : Map[@http.CaseInsensitiveString, String] = {
            "Content-Length": content.length().to_string(),
          }
          if ranged {
            headers["Content-Range"] = "bytes 3-4/5"
          }
          connection.send_response(
            if ranged {
              206
            } else {
              200
            },
            "OK",
            extra_headers=headers,
          )
          connection..write(content).end_response()
        }
        "/not-modified" =>
          connection
          ..send_response(304, "Not Modified", extra_headers={
            "Content-Length": "0",
          })
          .end_response()
        "/partial" => {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "9",
          })
          connection.write("abc")
          connection.flush()
          connection.close()
        }
        "/missing" =>
          connection
          ..send_response(404, "Not Found", extra_headers={
            "Content-Length": "0",
          })
          .end_response()
        "/header-stall" => {
          @async.sleep(500)
          connection..send_response(200, "OK").end_response()
        }
        "/body-stall" => {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "5",
          })
          connection.flush()
          @async.sleep(500)
          connection..write("later").end_response()
        }
        _ => connection..send_response(400, "Bad Request").end_response()
      }
    })
  }
  (server, server.addr.port())
}

///|
test "URL parser normalizes origins and remote names without exposing its type" {
  let first = @netops.parse_absolute_url(
    "HTTPS://Example.COM:443/a%20b?q=1#ignored",
  )
  let second = @netops.parse_absolute_url("https://example.com/a")
  assert_eq(first.origin_key(), second.origin_key())
  assert_eq(first.request_target(), "/a%20b?q=1")
  assert_eq(remote_name(first.to_url()), "a b")
  assert_eq(
    @netops.parse_absolute_url(first.to_url()).socket_host(),
    "Example.COM",
  )
  assert_true(proxy_bypassed(first.to_url(), Some("example.com")))
  assert_true(proxy_bypassed(first.to_url(), Some(".example.com:443")))
  assert_false(proxy_bypassed(first.to_url(), Some("ample.com")))
}

///|
test "empty no-proxy entries do not bypass trailing-dot hosts" {
  for list in ["", ",", " , ", "other.test,", ",other.test"] {
    assert_false(proxy_bypassed("http://a.co.uk./", Some(list)), msg=list)
  }
  assert_true(proxy_bypassed("http://a.co.uk./", Some("*")))
  assert_true(proxy_bypassed("http://a.co.uk./", Some("a.co.uk.")))
}

///|
test "redirect rewrites POST for 301/302/303 but preserves 307/308" {
  for status in [301, 302, 303] {
    assert_true(
      rewritten_request(status, Post, BytesBody(b"x"), false)
      is (Get, EmptyBody, true),
    )
  }
  for status in [307, 308] {
    assert_true(
      rewritten_request(status, Post, BytesBody(b"x"), false)
      is (Post, BytesBody(_), false),
    )
  }
  assert_true(
    rewritten_request(302, Patch, BytesBody(b"x"), true)
    is (Patch, EmptyBody, true),
  )
  assert_true(
    rewritten_request(302, Patch, FileBody("body"), true)
    is (Patch, FileBody("body"), false),
  )
}

///|
async test "cross-origin redirects strip authorization and partial failures clean output" {
  @async.with_task_group <| group => {
    let target = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => target.close())
    group.spawn_bg(no_wait=true) <| () => {
      target.run_forever() <| ((request, _, connection) => {
        let content = if request.headers.get("Authorization") is None {
          "clean"
        } else {
          "leaked"
        }
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": content.length().to_string(),
        })
        connection..write(content).end_response()
      })
    }
    let origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      origin.run_forever() <| ((_, _, connection) => {
        connection
        ..send_response(302, "Found", extra_headers={
          "Location": "http://127.0.0.1:\{target.addr.port()}/target",
          "Content-Length": "0",
        })
        .end_response()
      })
    }
    let path = "netops-cross-origin-\{@async.now()}.tmp"
    defer (try @sync_fs.remove_file(path) catch {
      _ => ()
    } noraise {
      _ => ()
    })
    ignore(
      transfer(
        "http://127.0.0.1:\{origin.addr.port()}/start",
        FileOutput(
          path~,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=true,
        ),
        options(
          headers=[@netops.http_header("Authorization", "Bearer secret")],
          redirects=FollowRedirects(3),
        ),
      ),
    )
    assert_eq(@fs.read_file(path).text(), "clean")
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    @fs.write_file(path, b"old")
    try
      transfer(
        "http://127.0.0.1:\{port}/partial",
        FileOutput(
          path~,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=true,
        ),
        options(),
      )
    catch {
      @netops.TransferError(kind=PartialBodyFailure, ..) => ()
      _ => fail("expected a partial-transfer failure")
    } noraise {
      _ => fail("expected a partial-transfer failure")
    }
    assert_false(@fs.exists(path))
  }
}
