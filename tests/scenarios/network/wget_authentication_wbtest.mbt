///|
test "authentication observer verifies the original proxy target including userinfo" {
  let absolute = "GET http://url%3Auser:urlpass@a.example.com:8123/public HTTP/1.1"
  let origin = "GET /public HTTP/1.1"
  let fields = "\r\nHost: a.example.com:8123\r\nAuthorization: Basic dXNlcjpwYXNz\r\n\r\n"
  for start in [absolute, origin] {
    assert_eq(
      authentication_request(
        (start, "", start + fields),
        b"\x00\xff",
        Some(absolute),
      ),
      (
        "/public",
        ["Basic dXNlcjpwYXNz"],
        "GET a.example.com:8123 /public auth=Basic dXNlcjpwYXNz body=00ff",
      ),
    )
  }
  for
    start in [
      "GET http://wrong:urlpass@a.example.com:8123/public HTTP/1.1", "GET http://a.example.com:8123/public HTTP/1.1",
      "GET http://url%3Auser:urlpass@other.example.com:8123/public HTTP/1.1", "GET http://url%3Auser:urlpass@a.example.com/public HTTP/1.1",
    ] {
    let accepted = try {
      ignore(
        authentication_request((start, "", start + fields), b"", Some(absolute)),
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
  let plain = "GET http://a.example.com/public HTTP/1.1"
  assert_eq(
    authentication_request(
      (plain, "", plain + "\r\nHost: a.example.com\r\n\r\n"),
      b"",
      Some(plain),
    ),
    ("/public", [], "GET a.example.com /public auth= body="),
  )
}

///|
test "authentication observer retains raw request bytes when validation fails" {
  let line = "POST http://unexpected@a.example.com/private HTTP/1.1"
  let raw = line + "\r\nHost: a.example.com\r\nContent-Length: 3\r\n\r\n"
  let body = b"\x00\xff\x01"
  let wires : Array[(String, Bytes)] = []
  let errors : Array[String] = []
  let accepted = try {
    ignore(
      authentication_observation((line, "", raw), body, None, wires, errors),
    )
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
  assert_eq(wires, [(raw, body)])
  assert_eq(errors.length(), 1)
  assert_false(errors[0].is_empty())
}
