///|
async fn wire_contract_upload_server(
  group : @async.TaskGroup[Unit],
  requests : Array[String],
  bodies : Array[Bytes],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      let request = StringBuilder()
      let mut length : Int32? = None
      while connection.read_until("\r\n") is Some(line) && line != "" {
        request.write_string(line + "\r\n")
        if line.to_lower().has_prefix("content-length:") {
          length = Some(@string.parse_int(line[15:].trim()))
        }
      }
      guard length is Some(length) else {
        fail("fixed upload fixture requires an observed Content-Length")
      }
      requests.push(request.to_string())
      bodies.push(connection.read_exactly(length))
      connection.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
    })
  })
  server
}

///|
async test "public transfer consumes informational responses before exposing the final response" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-interim-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      let server = serve_raw_response(
        group,
        "HTTP/1.1 100 Continue\r\n\r\n" +
        "HTTP/1.1 103 Early Hints\r\nLink: </early>; rel=preload\r\n\r\n" +
        "HTTP/1.1 200 OK\r\nContent-Length: 3\r\nX-Final: yes\r\n\r\nxyz",
      )
      let statuses : Array[Int32] = []
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/",
        FileOutput(
          path~,
          mode=Truncate,
          content_disposition=false,
          remove_on_error=false,
        ),
        transfer_options(),
        observer=event => {
          if event is ResponseStarted(status~, ..) {
            statuses.push(status)
          }
        },
      )
      assert_eq(result.status, 200)
      assert_eq(result.received, 3L)
      assert_eq(result.header("X-Final"), Some("yes"))
      assert_eq(result.header("Link"), None)
      assert_eq(statuses, [200])
      assert_eq(@fs.read_file(path).binary(), b"xyz")
    })
  })
}

///|
async test "public transfer preserves separate Set-Cookie fields and sends both stored cookies" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let requests : Array[String] = []
      let server = serve_raw_bytes_response(
        group,
        b"HTTP/1.1 200 OK\r\nSet-Cookie: first=one; Path=/; HttpOnly\r\nSet-Cookie: second=two; Path=/\r\nContent-Length: 0\r\n\r\n",
        requests~,
      )
      let jar = CookieJar::new()
      let url = "http://127.0.0.1:\{server.addr.port()}/"
      let result = transfer(
        url,
        DiscardOutput,
        transfer_options(cookie_jar=jar),
      )
      let cookies = result.headers.filter(header => {
        header.name.to_lower() == "set-cookie"
      })
      assert_eq(cookies.length(), 2)
      assert_true(cookies.any(header => header.value.has_prefix("first=one")))
      assert_true(cookies.any(header => header.value.has_prefix("second=two")))
      assert_true(jar.netscape().contains("\tfirst\tone\n"))
      assert_true(jar.netscape().contains("\tsecond\ttwo\n"))
      ignore(transfer(url, DiscardOutput, transfer_options(cookie_jar=jar)))
      assert_eq(requests.length(), 2)
      let sent_cookies = requests[1]
        .split("\r\n")
        .filter(line => line.to_owned().to_lower().has_prefix("cookie:"))
        .collect()
      assert_eq(sent_cookies.length(), 1)
      assert_true(sent_cookies[0].contains("first=one"))
      assert_true(sent_cookies[0].contains("second=two"))
    })
  })
}

///|
async test "public transfer uploads exact binary bytes with fixed lengths from memory and files" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-upload-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let payload : Bytes = [0, 1, 10, 13, 0x7f, 0x80, 0xff, 0, 65]
      let path = directory + "/input"
      @fs.write_file(path, payload)
      let requests : Array[String] = []
      let bodies : Array[Bytes] = []
      let server = wire_contract_upload_server(group, requests, bodies)
      for body in [BytesBody(payload), FileBody(path)] {
        let result = transfer(
          "http://127.0.0.1:\{server.addr.port()}/upload?mode=fixed",
          DiscardOutput,
          transfer_options(request_method=Put, body~),
        )
        assert_eq(result.status, 200)
        assert_eq(result.received, 2L)
      }
      assert_eq(bodies, [payload, payload])
      assert_eq(requests.length(), 2)
      for request in requests {
        assert_true(request.has_prefix("PUT /upload?mode=fixed HTTP/1.1\r\n"))
        assert_true(request.to_lower().contains("content-length: 9\r\n"))
        assert_false(request.to_lower().contains("transfer-encoding:"))
      }
    })
  })
}

///|
async test "public transfer reports request length failures before response or output effects" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-request-error-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/output"
      @fs.write_file(path, "preserve")
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((
          connection,
          _,
          // Do not race a response or a peer close against request validation.
        ) => ignore(connection.read_all()))
      })
      for declared_length in ["2", "8"] {
        let observed : Array[TransferEvent] = []
        try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(
              request_method=Post,
              headers=[http_header("Content-Length", declared_length)],
              body=BytesBody(b"abc"),
            ),
            observer=event => observed.push(event),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(kind, InputFailure)
            guard context is Some(context) else {
              fail("missing request context")
            }
            assert_eq(context.phase, Request)
            assert_eq(context.framing, None)
            assert_eq(context.received_bytes, 0L)
            assert_eq(context.committed_bytes, 0L)
            assert_false(context.write_outcome_uncertain)
          }
          error => raise error
        } noraise {
          _ => fail("mismatched request Content-Length must fail")
        }
        assert_true(observed.is_empty())
        assert_eq(@fs.read_file(path).text(), "preserve")
      }
    })
  })
}

///|
async test "public transfer rejects truncated and malformed headers before opening output" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-header-boundary-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for
        response in [
          "HTTP/1.1 20", "HTTP/1.1 100 Continue\r\n\r\n", "HTTP/1.1 200 OK\r\nContent-Length: 1",
          "HTTP/1.1 200 OK\nContent-Length: 1\n\nx", "HTTP/1.1 200 OK\r\nBad Header: value\r\n\r\n",
        ] {
        let server = serve_raw_response(group, response)
        for existing in [false, true] {
          let path = directory +
            (if existing { "/existing" } else { "/absent" })
          if existing {
            @fs.write_file(path, "preserve")
          }
          let observed : Array[TransferEvent] = []
          try
            transfer(
              "http://127.0.0.1:\{server.addr.port()}/",
              FileOutput(
                path~,
                mode=Truncate,
                content_disposition=false,
                remove_on_error=false,
              ),
              transfer_options(),
              observer=event => observed.push(event),
            )
          catch {
            TransferError(kind~, context~, ..) => {
              assert_eq(kind, ReceiveFailure)
              guard context is Some(context) else {
                fail("missing header context")
              }
              assert_eq(context.phase, ResponseHeaders)
              assert_eq(context.framing, None)
              assert_eq(context.received_bytes, 0L)
              assert_eq(context.committed_bytes, 0L)
              assert_false(context.write_outcome_uncertain)
            }
            error => raise error
          } noraise {
            _ => fail("incomplete or invalid response headers must fail")
          }
          assert_true(observed.is_empty())
          if existing {
            assert_eq(@fs.read_file(path).text(), "preserve")
          } else {
            assert_false(@fs.exists(path))
          }
        }
      }
    })
  })
}
