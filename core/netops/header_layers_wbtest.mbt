///|
async test "Cookie jar and explicit header remain separate across redirects" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let requests : Array[String] = []
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let buffer = Buffer()
          while true {
            let byte = connection.read_exactly(1)
            buffer.write_bytes(byte)
            if byte == b"\n" && buffer.to_bytes().has_suffix(b"\r\n\r\n") {
              break
            }
            guard buffer.length() < 16384 else {
              fail("request headers too large")
            }
          }
          let request = @utf8.decode(buffer.to_bytes())
          requests.push(request)
          let response = if request.has_prefix("GET /same ") {
            "HTTP/1.1 302 Found\r\nLocation: /cross\r\n"
          } else if request.has_prefix("GET /cross ") {
            "HTTP/1.1 302 Found\r\nLocation: http://localhost:\{server.addr.port()}/end\r\n"
          } else {
            "HTTP/1.1 200 OK\r\n"
          }
          connection.write(
            response + "Content-Length: 0\r\nConnection: close\r\n\r\n",
          )
        })
      })
      let jar = CookieJar::new()
      jar.load_netscape(
        "# Netscape HTTP Cookie File\n127.0.0.1\tFALSE\t/\tFALSE\t0\tsid\tstored\nlocalhost\tFALSE\t/\tFALSE\t0\tsid\tdestination\n",
      )
      for mode in [SeparateFields, ReplaceStored] {
        requests.clear()
        let result = transfer(
          "http://127.0.0.1:\{server.addr.port()}/same",
          DiscardOutput,
          transfer_options(
            headers=[http_header("cOoKiE", "sid=explicit")],
            cookie_jar=jar,
            custom_cookie_mode=mode,
            cookie_data="sid=ignored-when-custom-header",
            redirects=FollowRedirects(3),
          ),
        )
        assert_eq(result.status, 200)
        assert_eq(requests.length(), 3)
        let cookies = requests.map(request => {
          request
          .split("\r\n")
          .filter(line => line.to_owned().to_lower().has_prefix("cookie:"))
          .map(line => line.to_owned())
          .to_array()
        })
        assert_eq(
          cookies[0],
          match mode {
            SeparateFields => ["Cookie: sid=stored", "cOoKiE: sid=explicit"]
            ReplaceStored => ["cOoKiE: sid=explicit"]
          },
        )
        assert_eq(cookies[1], cookies[0])
        assert_eq(cookies[2], ["Cookie: sid=destination"])
      }
    })
  })
}
