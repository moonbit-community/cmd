///|
test "request URL preparation preserves escaped bytes and rejects raw request delimiters" {
  let escaped = "http://example.test/a%20b/%0D%0A?q=%00%7F#fragment"

  let parsed = @netops.parse_absolute_url(escaped).for_transfer()
  assert_eq(parsed.request_target(), "/a%20b/%0D%0A?q=%00%7F")
  assert_eq(parsed.endpoint, "example.test")

  for code in 0..<=127 {
    if code > 32 && code != 127 {
      continue
    }
    let character = code.to_char().unwrap().to_string()

    for
      url in [
        "http://example.test/a" + character + "b",
        "http://example.test/a?q=x" + character + "y",
        "http://example" + character + ".test/a",
      ] {
      try @netops.parse_absolute_url(url).for_transfer() catch {
        @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
      } noraise {
        _ => fail("raw HTTP delimiters must not reach serialization")
      }
    }
  }
}

///|
test "request URL preparation distinguishes initial URLs from redirect quoting" {
  let raw = @netops.parse_absolute_url(
    "http://example.test/a b\tc?q=x y\tz&escaped=%0D%0A",
  )
  assert_eq(
    raw.for_transfer(redirect=true).request_target(),
    "/a%20b%09c?q=x+y%09z&escaped=%0D%0A",
  )
  let base = @netops.parse_absolute_url("http://example.test/parent/child")
  let next = @netops.resolve_location(base, "../a b?q=x y").for_transfer(
    redirect=true,
  )
  assert_eq(next.to_url(), "http://example.test/a%20b?q=x+y")
}

///|
async test "public transfer rejects request line injection before connection and file effects" {
  @async.with_timeout(10000, () => {
    let directory = @fs.tmpdir(prefix="netops-request-target-")
    defer @async.protect_from_cancel(() => @fs.rmdir(directory, recursive=true))
    let path = directory + "/output"
    @fs.write_file(path, "preserve")
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()

    for
      suffix in [
        "/a\r\nX-Injected: yes", "/a?q=x\r\n\r\nGET /injected HTTP/1.1", "/a\nb",
        "/a\rb", "/a\tb", "/a b", "/a\u007fb",
      ] {
      let events : Array[TransferEvent] = []
      try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}" + suffix,
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition=false,
            remove_on_error=true,
          ),
          options(),
          observer=event => events.push(event),
        )
      catch {
        @netops.TransferError(kind~, ..) => assert_eq(kind, InvalidUrl)
        error => raise error
      } noraise {
        _ => fail("request injection must fail before network access")
      }
      assert_true(events.is_empty())
      assert_eq(@fs.read_file(path).binary(), b"preserve")
    }

    let accepted = @async.with_timeout_opt(50, () => server.accept())
    if accepted is Some((connection, _)) {
      connection.close()
      fail("rejected URLs must not open a connection")
    }
  })
}
