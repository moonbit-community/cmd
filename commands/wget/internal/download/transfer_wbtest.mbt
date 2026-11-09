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
async test "transfer streams fixed and unknown length responses to a file" {
  @async.with_task_group <| group => {
    let (server, port) = serve_test_requests(group)
    group.add_defer(() => server.close())
    let path = "netops-stream-\{@async.now()}.tmp"
    defer (try @sync_fs.remove_file(path) catch {
      _ => ()
    } noraise {
      _ => ()
    })
    let options = options(connect_timeout_ms=1000, idle_timeout_ms=1000)
    let output = FileOutput(
      path~,
      mode=Truncate,
      content_disposition=false,
      remove_on_error=false,
    )
    ignore(transfer("http://127.0.0.1:\{port}/fixed", output, options))
    assert_eq(@fs.read_file(path).text(), "hello")
    ignore(transfer("http://127.0.0.1:\{port}/chunked", output, options))
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
      transfer(
        "http://127.0.0.1:\{port}/missing",
        FileOutput(
          path~,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=false,
        ),
        options(
          fail_on_http_error=true,
          connect_timeout_ms=1000,
          idle_timeout_ms=1000,
        ),
      )
    catch {
      @netops.TransferError(kind=HttpStatusFailure, message~, ..) =>
        assert_true(message.contains("HTTP status 404 Not Found"))
      _ => fail("expected HTTP status error")
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
        transfer(
          "http://127.0.0.1:\{port}\{path}",
          DiscardOutput,
          options(connect_timeout_ms=100, idle_timeout_ms=100),
        )
      catch {
        @netops.TransferError(kind=TimeoutFailure, message~, ..) =>
          assert_true(message.contains("timed out after 100 milliseconds"))
        _ => fail("expected timeout error")
      } noraise {
        _ => fail("expected idle timeout")
      }
    }
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
      options(redirects=FollowRedirects(5)),
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
        options(redirects=FollowRedirects(5)),
      )
    catch {
      @netops.TransferError(kind=RedirectFailure, message~, ..) =>
        assert_true(message.contains("redirect loop"))
      _ => fail("expected redirect loop failure")
    } noraise {
      _ => fail("expected redirect loop failure")
    }
    try
      transfer(
        "http://127.0.0.1:\{port}/redirect-invalid",
        DiscardOutput,
        options(redirects=FollowRedirects(5)),
      )
    catch {
      @netops.TransferError(kind=RedirectFailure, ..) => ()
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
        options(request_method=Post, body=BytesBody(b"payload")),
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
        options(resume_from=3L),
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
        options(keep_output_on_not_modified=true),
      ),
    )
    assert_eq(@fs.read_file(unchanged).text(), "original")
  }
}
