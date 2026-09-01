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
          connection..write("hello").end_response()
        }
        "/chunked" => {
          connection.send_response(200, "OK")
          connection..write("slow-").flush()
          @async.sleep(5)
          connection..write("stream").end_response()
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
test "feedback modes and terminal progress are throttled" {
  assert_true(should_report_progress(Progress, true, 0L, 1000L, 0L, false))
  assert_false(should_report_progress(Progress, true, 1L, 1050L, 1000L, false))
  assert_true(should_report_progress(Progress, true, 1L, 1100L, 1000L, false))
  assert_true(should_report_progress(Summary, false, 0L, 1000L, 0L, false))
  assert_true(should_report_progress(Summary, false, 1L, 1000L, 1000L, true))
  assert_false(should_report_progress(ErrorsOnly, false, 1L, 1000L, 0L, true))
}
