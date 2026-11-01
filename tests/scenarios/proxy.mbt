///|
async fn run_connect_proxy(
  server : @socket.TcpServer,
  requests : Ref[Int32],
) -> Unit {
  server.run_forever() <| ((client, _) => {
    requests.val = requests.val + 1
    guard client.read_until("\r\n") is Some(line) else { return }
    while client.read_until("\r\n") is Some(header) && header != "" {

    }
    guard line.has_prefix("CONNECT ") && line.find(" HTTP/") is Some(end) else {
      client.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
      return
    }
    let authority = line[8:end].to_owned()
    let destination = @socket.Tcp::connect(@socket.Addr::parse(authority))
    defer destination.close()
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    @async.with_task_group <| relay => {
      relay.spawn_bg(no_wait=true) <| () => { client.write_reader(destination) }
      destination.write_reader(client)
    }
  })
}

///|
async fn run_proxy_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      origin.run_forever() <| ((_, _, connection) => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        connection..write("hello").end_response()
      })
    }
    let proxy = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => proxy.close())
    let proxy_requests = Ref(0)
    group.spawn_bg(no_wait=true, () => run_connect_proxy(proxy, proxy_requests))
    let proxy_url = "http://127.0.0.1:\{proxy.addr.port()}"
    let url = "http://127.0.0.1:\{origin.addr.port()}/fixed"

    let curl_proxy = @harness.run_command(
      bin_root,
      "curl",
      ["-s", "--proxy", proxy_url, "--noproxy", "", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_proxy = @harness.run_command(
      bin_root,
      "wget",
      ["-qO-", url],
      extra_env=Map([
        ("http_proxy", proxy_url),
        // Windows launchers collapse environment names without regard to case.
        // Both spellings must describe the same fixture proxy.
        ("HTTP_PROXY", proxy_url),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_proxy.status == 0 &&
      @harness.bytes_equal(curl_proxy.stdout, b"hello") &&
      wget_proxy.status == 0 &&
      @harness.bytes_equal(wget_proxy.stdout, b"hello") &&
      proxy_requests.val == 2,
      "HTTP CONNECT proxy transfer mismatch: curl status=\{curl_proxy.status} stdout=\{curl_proxy.stdout} stderr=\{curl_proxy.stderr}; wget status=\{wget_proxy.status} stdout=\{wget_proxy.stdout} stderr=\{wget_proxy.stderr}; connections=\{proxy_requests.val}",
      failures,
    )
    let curl_bypass = @harness.run_command(
      bin_root,
      "curl",
      ["-s", "--proxy", "http://127.0.0.1:1", "--noproxy", "127.0.0.1", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_bypass = @harness.run_command(
      bin_root,
      "wget",
      ["-qO-", "--no-proxy", url],
      extra_env=Map([
        ("http_proxy", "http://127.0.0.1:1"),
        ("HTTP_PROXY", "http://127.0.0.1:1"),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_bypass.status == 0 &&
      @harness.bytes_equal(curl_bypass.stdout, b"hello") &&
      wget_bypass.status == 0 &&
      @harness.bytes_equal(wget_bypass.stdout, b"hello") &&
      proxy_requests.val == 2,
      "proxy bypass mismatch: curl status=\{curl_bypass.status} stdout=\{curl_bypass.stdout} stderr=\{curl_bypass.stderr}; wget status=\{wget_bypass.status} stdout=\{wget_bypass.stdout} stderr=\{wget_bypass.stderr}; connections=\{proxy_requests.val}",
      failures,
    )
  }
}
