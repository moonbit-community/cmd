///|
async test "CONNECT retains tunnel bytes delivered with the final headers" {
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let requests : Array[String] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          while connection.read_until("\r\n") is Some(line) && line != "" {
            requests.push(line)
          }
          connection.write(b"HTTP/1.1 200 Connected\r\n\r\n\x00\xfftunnel")
        })
      })
      let parsed = {
        ..parse_absolute_url("http://example.test:8080/"),
        host: "a/c.xn--fa-hia.example",
        authority: "a/c.xn--fa-hia.example:8080",
        endpoint: "a/c.xn--fa-hia.example:8080",
        host_normalized: true,
      }
      let proxy = parse_absolute_url("http://127.0.0.1:\{server.addr.port()}")
      let connection = connect_endpoint(
        parsed,
        Some(proxy),
        @tls.NoVerification,
      )
      defer connection.close()
      let output = Buffer()
      while connection.read_some(max_len=32) is Some(bytes) {
        output.write_bytes(bytes)
      }
      assert_eq(requests[0], "CONNECT a/c.xn--fa-hia.example:8080 HTTP/1.1")
      assert_eq(output.to_bytes(), b"\x00\xfftunnel")
    })
  })
}
