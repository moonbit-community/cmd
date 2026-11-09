///|
async test "mapped hosts and relative redirects preserve request targets and credentials" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let tunnels : Array[String] = []
      let requests : Array[Array[String]] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let tunnel = connection.read_until("\r\n").unwrap()
          tunnels.push(tunnel)
          while connection.read_until("\r\n") is Some(line) && line != "" {
            ()
          }
          connection.write("HTTP/1.1 200 Connected\r\n\r\n")
          let fields : Array[String] = []
          while connection.read_until("\r\n") is Some(line) && line != "" {
            fields.push(line)
          }
          requests.push(fields)
          connection.write(
            if fields[0] == "GET /start HTTP/1.1" {
              "HTTP/1.1 302 Found\r\nLocation: /next\r\nContent-Length: 0\r\n\r\n"
            } else {
              "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
            },
          )
        })
      })

      for
        (input, expected) in [
          ("℀.faß.example", "a/c.xn--fa-hia.example"),
          ("foo＠bar.example", "foo@bar.example"),
          ("foo：80.bü.example", "foo:80.xn--b-eha.example"),
        ] {
        let index = requests.length()
        let result = transfer(
          "http://user:secret@" + input + ":8080/start",
          DiscardOutput,
          options(
            redirects=FollowRedirects(2),
            proxy_url="http://127.0.0.1:\{server.addr.port()}",
          ),
        )
        assert_eq(result.status, 200)
        assert_eq(requests.length(), index + 2)
        for step in 0..<2 {
          assert_eq(
            tunnels[index + step],
            "CONNECT " + expected + ":8080 HTTP/1.1",
          )
          assert_eq(
            requests[index + step][0],
            if step == 0 {
              "GET /start HTTP/1.1"
            } else {
              "GET /next HTTP/1.1"
            },
          )
          let wire_host = if expected.contains(":") {
            "[" + expected + "]"
          } else {
            expected
          }
          assert_true(
            requests[index + step].contains("Host: " + wire_host + ":8080"),
          )
          assert_true(
            requests[index + step].contains(
              "Authorization: Basic dXNlcjpzZWNyZXQ=",
            ),
          )
        }
      }
    })
  })
}

///|
async test "invalid bracketed hosts fail before connecting to a proxy" {
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let accepted : Array[Bool] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((_, _) => accepted.push(true))
      })
      for host in ["[localhost]", "[::1%25lo]"] {
        try
          transfer(
            "http://" + host + "/",
            DiscardOutput,
            options(proxy_url="http://127.0.0.1:\{server.addr.port()}"),
          )
        catch {
          @netops.TransferError(kind~, ..) => assert_eq(kind, ConnectionFailure)
          error => raise error
        } noraise {
          _ => fail("invalid bracketed host accepted")
        }
      }
      assert_eq(accepted.length(), 0)
    })
  })
}
