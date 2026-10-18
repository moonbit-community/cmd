///|
test "transfer disposition status fixture preserves status and incomplete wire bodies" {
  for
    (status, reason) in [
      (200, "OK"),
      (304, "Not Modified"),
      (404, "Not Found"),
      (500, "Internal Server Error"),
    ] {
    for
      (completion, content) in [
        ("empty-complete", "Content-Length: 0\r\n\r\n"),
        ("empty-incomplete", "Content-Length: 9\r\n\r\n"),
        ("body-complete", "Content-Length: 5\r\n\r\nhello"),
      ] {
      assert_eq(
        transfer_fixture_response(
          "/transfer-cd-status-\{status}-\{completion}",
          None,
        ),
        Some(
          "HTTP/1.1 \{status} \{reason}\r\nConnection: close\r\n" +
          "Content-Disposition: attachment; filename=\"selected.bin\"\r\n" +
          content,
        ),
      )
    }
  }
  assert_eq(
    transfer_fixture_response("/transfer-cd-status-201-body-complete", None),
    None,
  )
  assert_eq(
    transfer_fixture_response("/transfer-cd-status-200-unknown", None),
    None,
  )
}

///|
test "transfer fixture does not repair deliberately incomplete framing" {
  let prefix = transfer_fixture_response("/transfer-fixed-prefix", None).unwrap()
  assert_true(prefix.contains("Content-Length: 9\r\n\r\nhello"))
  let truncated = transfer_fixture_response("/transfer-chunk-terminator", None).unwrap()
  assert_true(truncated.has_suffix("5\r\nhello\r\n"))
  assert_false(truncated.has_suffix("0\r\n\r\n"))
  assert_true(
    transfer_fixture_response("/transfer-chunk-data-crlf", None)
    .unwrap()
    .has_suffix("5\r\nhello"),
  )
  assert_true(
    transfer_fixture_response("/transfer-chunk-complete", None)
    .unwrap()
    .has_suffix("5\r\nhello\r\n0\r\n\r\n"),
  )
  assert_eq(transfer_fixture_response("/transfer-header-empty", None), Some(""))
  assert_eq(
    transfer_fixture_response("/transfer-chunk-initial-eof", None),
    Some(
      "HTTP/1.1 200 OK\r\nConnection: close\r\nTransfer-Encoding: chunked\r\n\r\n",
    ),
  )
  assert_eq(
    transfer_fixture_response(
      "/transfer-resume-named-valid",
      None,
      request_method="HEAD",
    ),
    Some(
      "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Disposition: attachment; filename=renamed.bin\r\nContent-Length: 6\r\n\r\n",
    ),
  )
  assert_eq(
    transfer_fixture_response("/transfer-resume-named-valid", Some("bytes=3-")),
    Some(
      "HTTP/1.1 206 Partial Content\r\nConnection: close\r\nContent-Disposition: attachment; filename=renamed.bin\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\n\r\ndef",
    ),
  )
  assert_eq(
    transfer_fixture_response("/transfer-resume-named-valid", None),
    Some(
      "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Disposition: attachment; filename=renamed.bin\r\nContent-Length: 6\r\n\r\nabcdef",
    ),
  )
  assert_eq(
    transfer_fixture_response(
      "/transfer-resume-unsatisfied-malformed",
      Some("bytes=3-"),
    ),
    Some(
      "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\nContent-Range: bytes */bad\r\n\r\n",
    ),
  )
  assert_eq(
    transfer_fixture_response(
      "/transfer-resume-unsatisfied-missing",
      Some("bytes=3-"),
    ),
    Some(
      "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
    ),
  )
  assert_eq(transfer_fixture_response("/fixed", None), None)
  assert_eq(
    transfer_fixture_response("/transfer-named-empty", None),
    Some(
      "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Disposition: attachment; filename=\"first.bin\"\r\nContent-Length: 9\r\n\r\n",
    ),
  )
  for count in [4095, 4096] {
    for complete in [false, true] {
      let endpoint = if complete { "complete" } else { "partial" }
      let response = transfer_fixture_response(
        "/transfer-output-\{endpoint}-\{count}",
        None,
      ).unwrap()
      let advertised = count + (if complete { 0 } else { 1 })
      assert_eq(
        response,
        "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: \{advertised}\r\n\r\n" +
        String::make(count, 'x'),
      )
    }
  }
  assert_true(
    transfer_fixture_response("/transfer-resume-unsatisfied", Some("bytes=6-"))
    .unwrap()
    .has_suffix("Content-Range: bytes */6\r\n\r\n"),
  )
  assert_true(
    transfer_fixture_response(
      "/transfer-resume-nonfinal-range",
      Some("bytes=3-"),
    )
    .unwrap()
    .contains("Content-Length: 2\r\nContent-Range: bytes 3-4/6\r\n\r\nde"),
  )
}

///|
test "transfer retry fixture depends on the actual Range rather than call order" {
  for _ in 0..<2 {
    assert_true(
      transfer_fixture_response("/transfer-retry-range", None)
      .unwrap()
      .has_suffix("Content-Length: 10\r\n\r\nhello"),
    )
    assert_true(
      transfer_fixture_response("/transfer-retry-range", Some("bytes=5-"))
      .unwrap()
      .contains("Content-Range: bytes 5-9/10\r\n\r\nworld"),
    )
  }
  assert_true(
    transfer_fixture_response("/transfer-retry-range", Some("bytes=0-"))
    .unwrap()
    .has_prefix("HTTP/1.1 416"),
  )
  assert_true(
    transfer_fixture_response("/transfer-retry-ignore", Some("bytes=5-"))
    .unwrap()
    .has_suffix("\r\n\r\nhelloworld"),
  )
  assert_true(
    transfer_fixture_response(
      "/transfer-retry-ignore-changed",
      Some("bytes=5-"),
    )
    .unwrap()
    .has_suffix("\r\n\r\nXXXXXworld"),
  )
}

///|
async test "transfer fixture sends uncompleted wire bytes and closes the socket" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[TransferFixtureRequest] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, _, connection) => {
        assert_true(serve_transfer_fixture(request, connection, requests~))
      })
    })
    let expected_requests : Array[TransferFixtureRequest] = []
    for
      (request_method, path, range, expected) in [
        (
          "GET",
          "/transfer-chunk-terminator",
          None,
          "HTTP/1.1 200 OK\r\nConnection: close\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n",
        ),
        ("GET", "/transfer-header-empty", None, ""),
        (
          "GET",
          "/transfer-header-partial",
          None,
          "HTTP/1.1 200 OK\r\nContent-Len",
        ),
        (
          "HEAD",
          "/transfer-head-length",
          None,
          "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n",
        ),
        (
          "HEAD",
          "/transfer-resume-named-valid",
          None,
          "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Disposition: attachment; filename=renamed.bin\r\nContent-Length: 6\r\n\r\n",
        ),
        (
          "GET",
          "/transfer-resume-named-valid",
          Some("bytes=3-"),
          "HTTP/1.1 206 Partial Content\r\nConnection: close\r\nContent-Disposition: attachment; filename=renamed.bin\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\n\r\ndef",
        ),
        (
          "GET",
          "/transfer-retry-range",
          Some("bytes=5-"),
          "HTTP/1.1 206 Partial Content\r\nConnection: close\r\nContent-Length: 5\r\nContent-Range: bytes 5-9/10\r\n\r\nworld",
        ),
      ] {
      let completed = @async.with_timeout_opt(2000, () => {
        let client = @socket.Tcp::connect(server.addr)
        defer client.close()
        let range_header = range
          .map(value => "Range: " + value + "\r\n")
          .unwrap_or("")
        client.write(
          request_method +
          " " +
          path +
          " HTTP/1.1\r\nHost: fixture\r\n" +
          range_header +
          "\r\n",
        )
        client.read_all().text()
      })
      assert_eq(completed, Some(expected))
      expected_requests.push({ request_method, path, range, body: b"", })
    }
    for body in [b"\x00bin\xff", b""] {
      let completed = @async.with_timeout_opt(2000, () => {
        let client = @socket.Tcp::connect(server.addr)
        defer client.close()
        client.write(
          "PUT /transfer-stdin-retry HTTP/1.1\r\nHost: fixture\r\nExpect: 100-continue\r\nTransfer-Encoding: chunked\r\n\r\n",
        )
        assert_eq(client.read_until("\r\n"), Some("HTTP/1.1 100 Continue"))
        assert_eq(client.read_until("\r\n"), Some(""))
        if !body.is_empty() {
          client.write(b"5\r\n" + body + b"\r\n")
        }
        client.write("0\r\n\r\n")
        client.read_all().text()
      })
      assert_eq(
        completed,
        Some(
          if body.is_empty() {
            "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nok"
          } else {
            "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 9\r\n\r\nhello"
          },
        ),
      )
      expected_requests.push({
        request_method: "PUT",
        path: "/transfer-stdin-retry",
        range: None,
        body,
      })
    }
    assert_eq(requests, expected_requests)
  })
}

///|
async test "transfer fixture captures framed GET bytes before entering passthrough mode" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[TransferFixtureRequest] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, _, connection) => {
        assert_true(serve_transfer_fixture(request, connection, requests~))
      })
    })
    let body = b"\x00bin\xff"
    for chunked in [false, true] {
      let completed = @async.with_timeout_opt(2000, () => {
        let client = @socket.Tcp::connect(server.addr)
        defer client.close()
        client.write(
          "GET /transfer-fixed-complete HTTP/1.1\r\nHost: fixture\r\nExpect: 100-continue\r\n" +
          (if chunked {
            "Transfer-Encoding: chunked"
          } else {
            "Content-Length: 5"
          }) +
          "\r\n\r\n",
        )
        assert_eq(client.read_until("\r\n"), Some("HTTP/1.1 100 Continue"))
        assert_eq(client.read_until("\r\n"), Some(""))
        client.write(
          if chunked {
            b"5\r\n" + body + b"\r\n0\r\n\r\n"
          } else {
            body
          },
        )
        client.read_all().text()
      })
      assert_eq(
        completed,
        Some(
          "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 5\r\n\r\nhello",
        ),
      )
    }
    assert_eq(
      requests,
      Array::makei(2, _ => {
        request_method: "GET",
        path: "/transfer-fixed-complete",
        range: None,
        body,
      }),
    )
  })
}

///|
test "transfer retry lifecycle fixture requires a bounded per-run request capture" {
  let missing_error = try {
    ignore(transfer_retry_fixture_response("/transfer-retry-empty", None))
    None
  } catch {
    error => Some(error.to_string())
  }
  assert_true(
    missing_error.unwrap_or("").contains("requires per-run request capture"),
  )
  let requests : Array[TransferFixtureRequest] = Array::makei(2, _ => {
    request_method: "GET",
    path: "/transfer-retry-empty",
    range: None,
    body: b"",
  })
  let exhausted_error = try {
    ignore(
      transfer_retry_fixture_response("/transfer-retry-empty", Some(requests)),
    )
    None
  } catch {
    error => Some(error.to_string())
  }
  assert_true(
    exhausted_error.unwrap_or("").contains("exactly two requests per run"),
  )
}

///|
async test "transfer retry lifecycle fixture replays independently after request capture reset" {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[TransferFixtureRequest] = []
    let observed_before_response : Array[Int32] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, _, connection) => {
        assert_true(
          serve_transfer_fixture(request, connection, requests~, before_response=() => {
            observed_before_response.push(requests.length())
          }),
        )
      })
    })
    let fixed = "HTTP/1.1 200 OK\r\nConnection: close\r\n"
    let first_name = "Content-Disposition: attachment; filename=\"first.bin\"\r\n"
    let second_name = "Content-Disposition: attachment; filename=\"second.bin\"\r\n"
    for
      (path, first_headers, second_headers, second_body) in [
        ("/transfer-retry-empty", "", "", "Content-Length: 9\r\n\r\n"),
        ("/transfer-retry-complete", "", "", "Content-Length: 2\r\n\r\nok"),
        (
          "/transfer-retry-named-empty-changed", first_name, second_name, "Content-Length: 9\r\n\r\n",
        ),
        (
          "/transfer-retry-named-complete-changed", first_name, second_name, "Content-Length: 2\r\n\r\nok",
        ),
        (
          "/transfer-retry-named-complete-missing", first_name, "", "Content-Length: 2\r\n\r\nok",
        ),
      ] {
      for _ in 0..<2 {
        requests.clear()
        observed_before_response.clear()
        for
          expected in [
            fixed + first_headers + "Content-Length: 9\r\n\r\nhello",
            fixed + second_headers + second_body,
          ] {
          let completed = @async.with_timeout_opt(2000, () => {
            let client = @socket.Tcp::connect(server.addr)
            defer client.close()
            client.write("GET " + path + " HTTP/1.1\r\nHost: fixture\r\n\r\n")
            client.read_all().text()
          })
          assert_eq(completed, Some(expected))
        }
        assert_eq(observed_before_response, [1, 2])
        assert_eq(
          requests,
          Array::makei(2, _ => {
            request_method: "GET",
            path,
            range: None,
            body: b"",
          }),
        )
      }
    }
  })
}
