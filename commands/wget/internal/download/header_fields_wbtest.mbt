///|
async test "custom request fields retain curl repetition and wget replacement" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let requests : Array[Array[String]] = []
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let fields : Array[String] = []
          while connection.read_until("\r\n") is Some(line) && line != "" {
            if line.to_lower().has_prefix("x-marker:") ||
              line.to_lower().has_prefix("user-agent:") {
              fields.push(line)
            }
          }
          requests.push(fields)
          connection.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        })
      })

      ignore(
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          DiscardOutput,
          options(headers=[
            @netops.http_header("X-Marker", "first"),
            @netops.http_header("User-Agent", "custom"),
            @netops.http_header("x-marker", "second"),
          ]),
        ),
      )

      assert_eq(requests[0], ["User-Agent: custom", "X-Marker: second"])
    })
  })
}

///|
async test "response fields retain repetition casing and interleaved cookies" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(
        group,
        "HTTP/1.1 103 Early Hints\r\nX-Ignored: interim\r\n\r\n" +
        "HTTP/1.1 200 OK\r\nX-Value: first\r\nSet-Cookie: a=1\r\nx-value: second\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n\r\n",
      )
      let observed : Array[Array[HttpHeader]] = []
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/",
        DiscardOutput,
        options(),
        observer=event => {
          match event {
            ResponseStarted(headers~, ..) => observed.push(headers)
            _ => ()
          }
        },
      )
      let expected = [
        @netops.http_header("X-Value", "first"),
        @netops.http_header("Set-Cookie", "a=1"),
        @netops.http_header("x-value", "second"),
        @netops.http_header("Set-Cookie", "b=2"),
        @netops.http_header("Content-Length", "0"),
      ]
      assert_eq(result.headers, expected)
      assert_eq(observed, [expected])
    })
  })
}

///|
async test "Basic challenge lists distinguish schemes from quoted auth parameters" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        (fields, basic) in [
          (
            "WWW-Authenticate: Digest realm=\"first\"\r\nWWW-Authenticate: Basic realm=\"second\"\r\n",
            true,
          ),
          (
            "WWW-Authenticate: Basic realm=\"first\"\r\nWWW-Authenticate: Digest realm=\"second\"\r\n",
            true,
          ),
          (
            "WWW-Authenticate: Digest realm=\"a,b\", nonce=\"x\", bAsIc realm=\"second\"\r\n",
            true,
          ),
          (
            "WWW-Authenticate: Digest realm=\"a, Basic realm=\\\"fake\\\"\", nonce=\"x\"\r\n",
            false,
          ),
          (
            "WWW-Authenticate: Digest realm=\"a\", Basic=\"parameter\"\r\n", false,
          ),
          ("WWW-Authenticate: BasicPlus realm=\"a\"\r\n", false),
        ] {
        let requests : Array[String] = []
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        group.spawn_bg(no_wait=true, () => {
          server.run_forever((connection, _) => {
            let request = StringBuilder()
            while connection.read_until("\r\n") is Some(line) && line != "" {
              request.write_string(line + "\r\n")
            }
            requests.push(request.to_string())
            connection.write(
              "HTTP/1.1 401 Unauthorized\r\n" +
              fields +
              "Content-Length: 0\r\n\r\n",
            )
          })
        })
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            options(
              basic_user="user",
              basic_password="bad",
              basic_preemptive=false,
              fail_on_http_error=true,
            ),
          )
        catch {
          @netops.TransferError(kind~, ..) => Some(kind)
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(failure, Some(AuthenticationFailure))
        assert_eq(requests.length(), if basic { 2 } else { 1 })
        assert_false(requests[0].contains("Authorization:"))
        if basic {
          assert_true(
            requests[1].contains("Authorization: Basic dXNlcjpiYWQ=\r\n"),
          )
        }
      }
    })
  })
}
