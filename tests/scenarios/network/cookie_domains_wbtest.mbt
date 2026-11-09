///|
test "cookie Domain observer rejects changed hosts targets cookies and tunnel routes" {
  let absolute = "GET http://a.example.com/step/0 HTTP/1.1"
  let origin = "GET /step/0 HTTP/1.1"
  let fields = "\r\nHost: a.example.com\r\nCookie: sid=frozen\r\n"
  let tunnel = "CONNECT a.example.com:80 HTTP/1.1\r\nHost: 127.0.0.1:8123\r\n"
  let expected : Map[String, Json] = {
    "host_fields": [["Host: a.example.com"]],
    "request_targets": [Json(absolute)],
    "cookies": ["sid=frozen"],
    "requests": [
      { "lines": [Json(absolute), "Host: a.example.com", "Cookie: sid=frozen"] },
    ],
  }
  for candidate in [true, false] {
    let start = if candidate { origin } else { absolute }
    assert_eq(
      cookie_domain_requests(
        [(start, "sid=frozen", start + fields)],
        if candidate {
          [tunnel]
        } else {
          []
        },
        [0],
        0,
        expected,
        candidate~,
        proxy_authority="127.0.0.1:8123",
      ),
      ["sid=frozen"],
    )
  }
  for
    (start, cookie, wire, tunnels) in [
      ("GET /different HTTP/1.1", "sid=frozen", origin + fields, [tunnel]),
      (origin, "sid=changed", origin + fields, [tunnel]),
      (origin, "sid=frozen", origin + fields + "Cookie:\r\n", [tunnel]),
      (origin, "sid=frozen", origin + fields + "Authorization:\r\n", [tunnel]),
      (
        origin,
        "sid=frozen",
        origin + "\r\nHost: other.example.com\r\n",
        [tunnel],
      ),
      (
        origin,
        "sid=frozen",
        origin + fields + "Host: a.example.com\r\n",
        [tunnel],
      ),
      (
        origin,
        "sid=frozen",
        origin + fields,
        ["CONNECT other.example.com:80 HTTP/1.1\r\nHost: 127.0.0.1:8123\r\n"],
      ),
      (
        origin,
        "sid=frozen",
        origin + fields,
        ["CONNECT a.example.com:80 HTTP/1.1\r\nHost: wrong-proxy:8123\r\n"],
      ),
      (origin, "sid=frozen", origin + fields, []),
    ] {
    let accepted = try {
      ignore(
        cookie_domain_requests(
          [(start, cookie, wire)],
          tunnels,
          [0],
          0,
          expected,
          candidate=true,
          proxy_authority="127.0.0.1:8123",
        ),
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}

///|
test "cookie Domain observer rejects empty fields absent from the oracle" {
  let start = "GET http://a.example.com/step/0 HTTP/1.1"
  let headers = start + "\r\nHost: a.example.com\r\n"
  let expected : Map[String, Json] = {
    "host_fields": [["Host: a.example.com"]],
    "request_targets": [Json(start)],
    "cookies": [""],
    "requests": [{ "lines": [Json(start), "Host: a.example.com"] }],
  }
  ignore(
    cookie_domain_requests(
      [(start, "", headers)],
      [],
      [0],
      0,
      expected,
      candidate=false,
      proxy_authority="unused",
    ),
  )
  for field in ["Cookie:\r\n", "Authorization:\r\n"] {
    let accepted = try {
      ignore(
        cookie_domain_requests(
          [(start, "", headers + field)],
          [],
          [0],
          0,
          expected,
          candidate=false,
          proxy_authority="unused",
        ),
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}
