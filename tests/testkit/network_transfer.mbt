///|
pub(all) struct TransferFixtureRequest {
  request_method : String
  path : String
  range : String?
  body : Bytes
  cookies : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub extend TransferFixtureRequest with @debug.Debug::{to_repr}

///|
pub extend TransferFixtureRequest with Eq::{equal, not_equal}

///|
pub extend TransferFixtureRequest with ToJson::{to_json}

///|
fn transfer_disposition_status_response(path : String) -> String? {
  for
    (status, reason) in [
      (200, "OK"),
      (304, "Not Modified"),
      (404, "Not Found"),
      (500, "Internal Server Error"),
    ] {
    for
      (completion, length, body) in [
        ("empty-complete", 0, ""),
        ("empty-incomplete", 9, ""),
        ("body-complete", 5, "hello"),
      ] {
      if path == "/transfer-cd-status-\{status}-\{completion}" {
        return Some(
          "HTTP/1.1 \{status} \{reason}\r\nConnection: close\r\n" +
          "Content-Disposition: attachment; filename=\"selected.bin\"\r\n" +
          "Content-Length: \{length}\r\n\r\n" +
          body,
        )
      }
    }
  }
  None
}

///|
/// These are complete wire responses, including deliberately absent framing
/// bytes. They must never pass through the HTTP response encoder.
fn transfer_fixture_response(
  path : String,
  range : String?,
  request_method~ : String = "GET",
) -> String? {
  if transfer_disposition_status_response(path) is Some(response) {
    return Some(response)
  }
  let fixed = "HTTP/1.1 200 OK\r\nConnection: close\r\n"
  let chunked = fixed + "Transfer-Encoding: chunked\r\n\r\n"
  match path {
    "/transfer-chunk-initial-eof" => Some(chunked)
    "/transfer-fixed-empty" => Some(fixed + "Content-Length: 9\r\n\r\n")
    "/transfer-fixed-prefix" => Some(fixed + "Content-Length: 9\r\n\r\nhello")
    "/transfer-output-partial-4095"
    | "/transfer-output-partial-4096"
    | "/transfer-output-complete-4095"
    | "/transfer-output-complete-4096" => {
      let count = if path.has_suffix("4095") { 4095 } else { 4096 }
      let advertised = count + (if path.contains("-partial-") { 1 } else { 0 })
      Some(
        fixed +
        "Content-Length: \{advertised}\r\n\r\n" +
        String::make(count, 'x'),
      )
    }
    "/transfer-chunk-empty" => Some(chunked + "5\r\n")
    "/transfer-chunk-payload" => Some(chunked + "9\r\nhello")
    "/transfer-chunk-data-crlf" => Some(chunked + "5\r\nhello")
    "/transfer-chunk-terminator" => Some(chunked + "5\r\nhello\r\n")
    "/transfer-chunk-trailer" =>
      Some(chunked + "5\r\nhello\r\n0\r\nX-Trace: fixture\r\n")
    "/transfer-chunk-invalid" => Some(chunked + "not-hex\r\n")
    "/transfer-fixed-complete" => Some(fixed + "Content-Length: 5\r\n\r\nhello")
    "/transfer-empty-complete" => Some(fixed + "Content-Length: 0\r\n\r\n")
    "/transfer-chunk-complete" => Some(chunked + "5\r\nhello\r\n0\r\n\r\n")
    "/transfer-trailer-complete" =>
      Some(chunked + "5\r\nhello\r\n0\r\nX-Trace: fixture\r\n\r\n")
    "/transfer-close-complete" => Some(fixed + "\r\nhello")
    "/transfer-header-empty" => Some("")
    "/transfer-header-partial" => Some("HTTP/1.1 200 OK\r\nContent-Len")
    "/transfer-head-length" =>
      Some("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n")
    "/transfer-no-content" =>
      Some("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
    "/transfer-not-modified" =>
      Some(
        "HTTP/1.1 304 Not Modified\r\nConnection: close\r\nContent-Length: 9\r\n\r\n",
      )
    "/transfer-named-prefix" =>
      Some(
        fixed +
        "Content-Length: 9\r\nContent-Disposition: attachment; filename=wire-partial.bin\r\n\r\nhello",
      )
    "/transfer-named-empty" =>
      Some(
        fixed +
        "Content-Disposition: attachment; filename=\"first.bin\"\r\nContent-Length: 9\r\n\r\n",
      )
    "/transfer-resume-name-change" =>
      Some(
        "HTTP/1.1 206 Partial Content\r\nConnection: close\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\nContent-Disposition: attachment; filename=renamed.bin\r\n\r\ndef",
      )
    "/transfer-resume-name-change-ignore" =>
      Some(
        fixed +
        "Content-Length: 6\r\nContent-Disposition: attachment; filename=renamed.bin\r\n\r\nabcdef",
      )
    "/transfer-resume-named-valid" => {
      let disposition = "Content-Disposition: attachment; filename=renamed.bin\r\n"
      if request_method == "HEAD" {
        Some(fixed + disposition + "Content-Length: 6\r\n\r\n")
      } else if range == Some("bytes=3-") {
        Some(
          "HTTP/1.1 206 Partial Content\r\nConnection: close\r\n" +
          disposition +
          "Content-Length: 3\r\nContent-Range: bytes 3-5/6\r\n\r\ndef",
        )
      } else if range is None {
        Some(fixed + disposition + "Content-Length: 6\r\n\r\nabcdef")
      } else {
        Some(
          "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\nContent-Range: bytes */6\r\n\r\n",
        )
      }
    }
    "/transfer-resume-unsatisfied" =>
      Some(
        "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\nContent-Range: bytes */6\r\n\r\n",
      )
    "/transfer-resume-unsatisfied-malformed" =>
      Some(
        "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\nContent-Range: bytes */bad\r\n\r\n",
      )
    "/transfer-resume-unsatisfied-missing" =>
      Some(
        "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
      )
    "/transfer-resume-nonfinal-range" =>
      Some(
        "HTTP/1.1 206 Partial Content\r\nConnection: close\r\nContent-Length: 2\r\nContent-Range: bytes 3-4/6\r\n\r\nde",
      )
    "/transfer-retry-range"
    | "/transfer-retry-ignore"
    | "/transfer-retry-ignore-changed"
    | "/transfer-retry-wrong-range"
    | "/transfer-retry-named" => {
      let attachment = if path == "/transfer-retry-named" {
        "Content-Disposition: attachment; filename=wire-retry.bin\r\n"
      } else {
        ""
      }
      match range {
        None => Some(fixed + attachment + "Content-Length: 10\r\n\r\nhello")
        Some("bytes=5-") =>
          if path == "/transfer-retry-ignore" ||
            path == "/transfer-retry-ignore-changed" {
            Some(
              fixed +
              "Content-Length: 10\r\n\r\n" +
              (if path == "/transfer-retry-ignore-changed" {
                "XXXXXworld"
              } else {
                "helloworld"
              }),
            )
          } else {
            let content_range = if path == "/transfer-retry-wrong-range" {
              "bytes 6-10/11"
            } else {
              "bytes 5-9/10"
            }
            Some(
              "HTTP/1.1 206 Partial Content\r\nConnection: close\r\n" +
              attachment +
              "Content-Length: 5\r\nContent-Range: " +
              content_range +
              "\r\n\r\nworld",
            )
          }
        Some(_) =>
          Some(
            "HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
          )
      }
    }
    _ => None
  }
}

///|
fn transfer_retry_fixture_response(
  path : String,
  requests : Array[TransferFixtureRequest]?,
) -> String? raise {
  guard [
    "/transfer-retry-empty", "/transfer-retry-complete", "/transfer-retry-named-empty-changed",
    "/transfer-retry-named-complete-changed", "/transfer-retry-named-complete-missing",
  ].contains(path) else {
    return None
  }
  guard requests is Some(requests) else {
    fail("retry lifecycle fixture requires per-run request capture")
  }
  let count = requests.filter(previous => previous.path == path).length()
  guard count < 2 else {
    fail("retry lifecycle fixture expects exactly two requests per run")
  }
  let disposition = if !path.contains("-named-") {
    ""
  } else if count == 0 {
    "Content-Disposition: attachment; filename=\"first.bin\"\r\n"
  } else if path.has_suffix("-changed") {
    "Content-Disposition: attachment; filename=\"second.bin\"\r\n"
  } else {
    ""
  }
  let content = if count == 0 {
    "Content-Length: 9\r\n\r\nhello"
  } else if path.contains("-complete") {
    "Content-Length: 2\r\n\r\nok"
  } else {
    "Content-Length: 9\r\n\r\n"
  }
  Some("HTTP/1.1 200 OK\r\nConnection: close\r\n" + disposition + content)
}

///|
/// Public passthrough mode writes directly to the underlying TCP connection.
/// Closing here prevents run_forever from completing a truncated response.
pub async fn serve_transfer_fixture(
  request : @http.Request,
  connection : @http.ServerConnection,
  requests? : Array[TransferFixtureRequest],
  before_response? : async () -> Unit,
) -> Bool {
  let range = request.headers.get("Range")
  let request_method = oracle_request_name(request)
  let upload = request.path == "/transfer-stdin-retry" ||
    request.path == "/transfer-stdin-redirect" ||
    request.path == "/transfer-stdin-replayed"
  let response = if transfer_retry_fixture_response(request.path, requests)
    is Some(response) {
    Some(response)
  } else {
    transfer_fixture_response(request.path, range, request_method~)
  }
  guard upload || response is Some(_) else { return false }
  if request.headers
    .get("Expect")
    .unwrap_or("")
    .to_lower()
    .contains("100-continue") {
    connection..send_response(100, "Continue").end_response()
  }
  let body = connection.read_all().binary()
  let response = if upload {
    Some(
      if request.path == "/transfer-stdin-redirect" {
        "HTTP/1.1 307 Temporary Redirect\r\nConnection: close\r\nLocation: /transfer-stdin-replayed\r\nContent-Length: 0\r\n\r\n"
      } else if request.path == "/transfer-stdin-retry" && !body.is_empty() {
        "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 9\r\n\r\nhello"
      } else {
        "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nok"
      },
    )
  } else {
    response
  }
  guard response is Some(response) else { return false }
  if requests is Some(requests) {
    requests.push({
      request_method,
      path: request.path,
      range,
      body,
      cookies: request.headers.get("Cookie").map(value => [value]).unwrap_or([]),
    })
  }
  if before_response is Some(observe) {
    observe()
  }
  connection.enter_passthrough_mode()
  defer connection.close()
  if response != "" {
    connection.write(response)
  }
  true
}

///|
fn wire_cookie_steps(label : String) -> Array[Array[String]]? {
  match label {
    "no-pair" => Some([["broken", "valid=ok; Path=/"]])
    "invalid-maxage" =>
      Some([["odd=value; Max-Age=nope; Path=/", "valid=ok; Path=/"]])
    "seeded-invalid-maxage" =>
      Some([
        ["sid=old; Path=/"],
        ["sid=new; Max-Age=nope; Path=/", "valid=ok; Path=/"],
      ])
    "duplicate-valid-invalid" =>
      Some([
        [
          "sid=good; Path=/", "sid=bad; Max-Age=nope; Path=/", "valid=ok; Path=/",
        ],
      ])
    "duplicate-invalid-valid" =>
      Some([
        [
          "sid=bad; Max-Age=nope; Path=/", "sid=good; Path=/", "valid=ok; Path=/",
        ],
      ])
    "order-name-length" =>
      Some([["a=1; Path=/", "longname=2; Path=/", "bb=3; Path=/"]])
    "order-equal-length" =>
      Some([["aa=1; Path=/", "bb=2; Path=/", "cc=3; Path=/"]])
    "order-equal-reverse" =>
      Some([["cc=3; Path=/", "bb=2; Path=/", "aa=1; Path=/"]])
    "order-replace" =>
      Some([["aa=1; Path=/", "bb=2; Path=/"], ["aa=3; Path=/"]])
    "order-invalid-valid-cross" =>
      Some([
        ["sid=old; Path=/"],
        ["sid=bad; Max-Age=nope; Path=/"],
        ["sid=new; Path=/"],
      ])
    "maxage-overflow-one" =>
      Some([
        ["sid=old; Path=/"],
        ["sid=new; Max-Age=9223372036854775808; Path=/", "valid=ok; Path=/"],
      ])
    "maxage-overflow-many" =>
      Some([
        ["sid=old; Path=/"],
        [
          "sid=new; Max-Age=999999999999999999999999999999; Path=/", "valid=ok; Path=/",
        ],
      ])
    _ => None
  }
}

///|
fn wire_fixture_response(
  target : String,
  cookies : Array[String],
) -> String raise {
  let fixed = "HTTP/1.1 200 OK\r\nConnection: close\r\n"
  if target.has_prefix("/wire-url/") {
    return fixed + "Content-Length: 2\r\n\r\nok"
  }
  for
    (label, value) in [
      ("space", " "),
      ("tab", "\t"),
      ("escaped-crlf", "%0D%0A"),
    ] {
    for part in ["path", "query"] {
      if target == "/wire-redirect-\{part}-\{label}" {
        let location = if part == "path" {
          "/wire-url/next-a" + value + "b"
        } else {
          "/wire-url/next?q=a" + value + "b"
        }
        return "HTTP/1.1 302 Found\r\nConnection: close\r\nContent-Length: 0\r\nLocation: " +
          location +
          "\r\n\r\n"
      }
    }
  }
  for
    label in [
      "no-pair", "invalid-maxage", "seeded-invalid-maxage", "duplicate-valid-invalid",
      "duplicate-invalid-valid", "order-name-length", "order-equal-length", "order-equal-reverse",
      "order-replace", "order-invalid-valid-cross", "maxage-overflow-one", "maxage-overflow-many",
    ] {
    let base = "/wire-cookie-" + label
    let steps = wire_cookie_steps(label).unwrap()
    for index in 0..<=steps.length() {
      let path = if index == 0 { base } else { base + "/hop-\{index}" }
      if target == path {
        if index == steps.length() {
          let body = cookies.map(value => "Cookie: " + value).join("\n")
          return fixed +
            "Content-Length: \{@utf8.encode(body).length()}\r\n\r\n" +
            body
        }
        let fields = steps[index]
          .map(value => "Set-Cookie: " + value + "\r\n")
          .join("")
        return "HTTP/1.1 302 Found\r\nConnection: close\r\nContent-Length: 0\r\nLocation: " +
          base +
          "/hop-\{index + 1}\r\n" +
          fields +
          "\r\n"
      }
    }
  }
  fail("unknown raw wire fixture request target: " + target)
}

///|
/// This diagnostic fixture observes the request target before URL or HTTP parsing.
/// It accepts only bounded bodyless GET requests and preserves repeated Cookie fields.
pub async fn serve_wire_fixture(
  connection : @socket.Tcp,
  requests : Array[TransferFixtureRequest],
  request_wires : Array[Bytes],
) -> Unit {
  defer connection.close()
  @async.with_timeout(8000, () => {
    guard connection.read_until("\r\n") is Some(start) else { return }
    let fields = start.split(" ").to_array()
    guard fields.length() == 3 && fields[0] == "GET" && fields[2] == "HTTP/1.1" else {
      fail(
        "wire fixture received an invalid or unsupported request line: " + start,
      )
    }
    let target = fields[1].to_owned()
    let cookies : Array[String] = []
    let mut range : String? = None
    let mut wire = start + "\r\n"
    for ;; {
      guard connection.read_until("\r\n") is Some(line) else {
        fail("EOF in wire fixture request headers")
      }
      wire += line + "\r\n"
      guard wire.length() <= 16384 else {
        fail("wire fixture request exceeds 16 KiB")
      }
      if line == "" {
        break
      }
      guard line.find(":") is Some(colon) else {
        fail("wire fixture received malformed header")
      }
      let name = line[:colon].to_owned().to_lower()
      let value = line[colon + 1:].trim().to_owned()
      if name == "cookie" {
        cookies.push(value)
      }
      if name == "range" {
        range = Some(value)
      }
      guard name != "transfer-encoding" &&
        (name != "content-length" || value == "0") else {
        fail("wire fixture requires a bodyless GET")
      }
    }
    request_wires.push(@utf8.encode(wire))
    requests.push({
      request_method: "GET",
      path: target,
      range,
      body: b"",
      cookies,
    })
    connection.write(wire_fixture_response(target, cookies))
  })
}
