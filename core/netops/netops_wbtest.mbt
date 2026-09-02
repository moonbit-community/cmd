///|
async fn serve_test_requests(
  group : @async.TaskGroup[Unit],
) -> (@http.Server, Int) {
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
          connection.send_response(if ranged { 206 } else { 200 }, "OK", extra_headers={
            "Content-Length": content.length().to_string(),
          })
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
          @async.sleep(200)
          connection..send_response(200, "OK").end_response()
        }
        "/body-stall" => {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "5",
          })
          connection.flush()
          @async.sleep(200)
          connection..write("later").end_response()
        }
        _ => connection..send_response(400, "Bad Request").end_response()
      }
    })
  }
  (server, server.addr.port())
}

///|
async test "fetch streams fixed and unknown length responses to a file" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    let path = "netops-stream-\{@async.now()}.tmp"
    defer (try @sync_fs.remove_file(path) catch {
      _ => ()
    } noraise {
      _ => ()
    })
    let options = fetch_options(false, 1000, false, "test")
    fetch_with_options("http://127.0.0.1:\{port}/fixed", Some(path), options)
    assert_eq(@fs.read_file(path).text(), "hello")
    fetch_with_options("http://127.0.0.1:\{port}/chunked", Some(path), options)
    assert_eq(@fs.read_file(path).text(), "slow-stream")
  }
}

///|
async test "HTTP errors are readable and do not create the output file" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    let path = "netops-error-\{@async.now()}.tmp"
    if @fs.exists(path) {
      @sync_fs.remove_file(path)
    }
    try
      fetch_with_options(
        "http://127.0.0.1:\{port}/missing",
        Some(path),
        fetch_options(true, 1000, false, "test"),
      )
    catch {
      NetOpError(message) =>
        assert_true(message.contains("HTTP status 404 Not Found"))
      _ => fail("expected NetOpError")
    } noraise {
      _ => fail("expected HTTP status failure")
    }
    assert_false(@fs.exists(path))
  }
}

///|
async test "request and body reads enforce idle timeout" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    for path in ["/header-stall", "/body-stall"] {
      try
        fetch_with_options(
          "http://127.0.0.1:\{port}\{path}",
          None,
          fetch_options(false, 20, false, "test"),
        )
      catch {
        NetOpError(message) =>
          assert_true(message.contains("timed out after 20 milliseconds"))
        _ => fail("expected NetOpError")
      } noraise {
        _ => fail("expected idle timeout")
      }
    }
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
test "URL parser normalizes origins and remote names without exposing its type" {
  let first = parse_absolute_url("HTTPS://Example.COM:443/a%20b?q=1#ignored")
  let second = parse_absolute_url("https://example.com/a")
  assert_eq(first.origin_key(), second.origin_key())
  assert_eq(first.request_target(), "/a%20b?q=1")
  assert_eq(remote_name(first.to_url()), "a b")
  assert_eq(url_host(first.to_url()), "Example.COM")
  assert_true(proxy_bypassed(first.to_url(), Some("example.com")))
  assert_true(proxy_bypassed(first.to_url(), Some(".example.com:443")))
  assert_false(proxy_bypassed(first.to_url(), Some("ample.com")))
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
}

///|
async test "transfer follows RFC-relative redirects and detects loops" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    let events : Array[TransferEvent] = []
    let result = transfer(
      "http://127.0.0.1:\{port}/redirect-a",
      DiscardOutput,
      transfer_options(redirects=FollowRedirects(5)),
      observer=event => events.push(event),
    )
    assert_eq(result.status, 200)
    assert_eq(result.redirects, 1)
    assert_eq(result.received, 5L)
    assert_true(events[0] is ResponseStarted(status=302, ..))
    assert_true(events[1] is Redirected(status=302, ..))
    assert_true(events[2] is ResponseStarted(status=200, ..))
    try
      transfer(
        "http://127.0.0.1:\{port}/redirect-loop",
        DiscardOutput,
        transfer_options(redirects=FollowRedirects(5)),
      )
    catch {
      TransferError(kind=RedirectFailure, message~, ..) =>
        assert_true(message.contains("redirect loop"))
      _ => fail("expected redirect loop failure")
    } noraise {
      _ => fail("expected redirect loop failure")
    }
    try
      transfer(
        "http://127.0.0.1:\{port}/redirect-invalid",
        DiscardOutput,
        transfer_options(redirects=FollowRedirects(5)),
      )
    catch {
      TransferError(kind=RedirectFailure, ..) => ()
      _ => fail("expected redirect target failure")
    } noraise {
      _ => fail("expected redirect target failure")
    }
  }
}

///|
async test "transfer streams request bodies, resumes, and preserves 304 output" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    let base = "http://127.0.0.1:\{port}"
    let echoed = "netops-echo-\{@async.now()}.tmp"
    let resumed = "netops-resume-\{@async.now()}.tmp"
    let unchanged = "netops-unchanged-\{@async.now()}.tmp"
    defer (for path in [echoed, resumed, unchanged] {
      try @sync_fs.remove_file(path) catch {
        _ => ()
      } noraise {
        _ => ()
      }
    })
    ignore(
      transfer(
        base + "/echo",
        FileOutput(
          path=echoed,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=true,
        ),
        transfer_options(request_method=Post, body=BytesBody(b"payload")),
      ),
    )
    assert_eq(@fs.read_file(echoed).text(), "payload")
    @fs.write_file(resumed, b"hel")
    ignore(
      transfer(
        base + "/range",
        FileOutput(
          path=resumed,
          mode=Append,
          content_disposition=false,
          remove_on_error=false,
        ),
        transfer_options(resume_from=3L),
      ),
    )
    assert_eq(@fs.read_file(resumed).text(), "hello")
    @fs.write_file(unchanged, b"original")
    ignore(
      transfer(
        base + "/not-modified",
        FileOutput(
          path=unchanged,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=false,
        ),
        transfer_options(keep_output_on_not_modified=true),
      ),
    )
    assert_eq(@fs.read_file(unchanged).text(), "original")
  }
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
        transfer_options(
          headers=[http_header("Authorization", "Bearer secret")],
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
        transfer_options(),
      )
    catch {
      TransferError(kind=ConnectionFailure, ..) => ()
      _ => fail("expected a partial-transfer failure")
    } noraise {
      _ => fail("expected a partial-transfer failure")
    }
    assert_false(@fs.exists(path))
  }
}
