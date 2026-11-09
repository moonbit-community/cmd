///|
test "request URL preparation preserves escaped bytes and rejects raw request delimiters" {
  let escaped = "http://example.test/a%20b/%0D%0A?q=%00%7F#fragment"

  let parsed = @netops.parse_absolute_url(escaped).for_transfer()
  assert_eq(parsed.request_target(), "/a%20b/%0D%0A?q=%00%7F")
  assert_eq(parsed.endpoint, "example.test")
}

///|
test "request URL preparation distinguishes initial URLs from redirect quoting" {
  let raw = @netops.parse_absolute_url(
    "http://example.test/a b\tc?q=x y\tz&escaped=%0D%0A",
  )
  assert_eq(
    raw.for_transfer().request_target(),
    "/a%20b%09c?q=x%20y%09z&escaped=%0D%0A",
  )
}

///|
async test "public transfer quotes Wget request controls without adding headers or requests" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let requests : Array[String] = []
      let server = serve_raw_bytes_response(
        group,
        b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
        requests~,
      )
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/a\r\nX-Injected: yes?q=\tdata",
        DiscardOutput,
        options(),
      )
      assert_eq(result.status, 200)
      assert_eq(result.received, 2L)
      assert_eq(requests.length(), 1)
      assert_true(
        requests[0].has_prefix(
          "GET /a%0D%0AX-Injected:%20yes?q=%09data HTTP/1.1\r\n",
        ),
      )
      assert_false(requests[0].contains("\r\nX-Injected:"))
    })
  })
}
