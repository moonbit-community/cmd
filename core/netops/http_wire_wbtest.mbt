///|
async test "wire chunked framing overrides Content-Length and accepts extensions and trailers" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nTransfer-Encoding: Chunked\r\nContent-Length: 999\r\n\r\n5;name=value\r\nhello\r\n0\r\nX-Trailer: yes\r\n\r\n",
      )
      with_response(
        exchange_test_request(server.addr.port()),
        exchange_test_transport(),
        scope => {
          assert_eq(scope.head().framing, Chunked)
          assert_true(
            scope.head().fields.contains(http_header("Content-Length", "999")),
          )
          let body = Buffer()
          for ;; {
            match scope.read() {
              Data(bytes) => body.write_bytes(bytes)
              End => break
              Incomplete(_) => fail("complete fixture reported partial framing")
            }
          }
          assert_eq(body.to_bytes(), b"hello")
        },
      )
    })
  })
}

///|
async test "wire unknown length uploads stream independent chunks and a final terminator" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let frames : Array[Bytes] = []
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let expected = b"3\r\none\r\n3\r\ntwo\r\n0\r\n\r\n"
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let headers = StringBuilder()
          while connection.read_until("\r\n") is Some(line) && line != "" {
            headers.write_string(line + "\r\n")
          }
          assert_true(
            headers.to_string().contains("Transfer-Encoding: chunked\r\n"),
          )
          assert_false(headers.to_string().contains("Content-Length:"))
          frames.push(connection.read_exactly(expected.length()))
          connection.write(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        })
      })
      let parsed = parse_absolute_url(
        "http://127.0.0.1:\{server.addr.port()}/upload",
      )
      let transport : Transport = {
        proxy: None,
        verify_tls: true,
        connect_timeout_ms: 10000,
        idle_timeout_ms: 10000,
        deadline_ms: None,
      }
      let wire = open_transport(parsed, transport)
      defer wire.close()
      wire.start_exchange(
        {
          target: parsed,
          host: parsed.endpoint,
          request_method: Post,
          headers: [],
          body: StdinBody,
        },
        transport,
      )
      wire.write_exchange_payload(b"one", transport)
      wire.write_exchange_payload(b"", transport)
      wire.write_exchange_payload(b"two", transport)
      wire.write_exchange_body(EmptyBody, transport)
      assert_eq(wire.request_payload_bytes, 6L)
      let response = wire.response(Post)
      assert_eq(response.code, 200)
      assert_eq(frames, [expected])
    })
  })
}
