///|
pub(all) struct TransferFixtureRequest {
  request_method : String
  path : String
  range : String?
  body : Bytes
} derive(Debug, Eq, ToJson)

///|
pub extend TransferFixtureRequest with @debug.Debug::{to_repr}

///|
pub extend TransferFixtureRequest with Eq::{equal, not_equal}

///|
pub extend TransferFixtureRequest with ToJson::{to_json}

///|
/// These are complete wire responses, including deliberately absent framing
/// bytes. They must never pass through the HTTP response encoder.
fn transfer_fixture_response(
  path : String,
  range : String?,
  request_method~ : String = "GET",
) -> String? {
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
/// Public passthrough mode writes directly to the underlying TCP connection.
/// Closing here prevents run_forever from completing a truncated response.
pub async fn serve_transfer_fixture(
  request : @http.Request,
  connection : @http.ServerConnection,
  requests? : Array[TransferFixtureRequest],
) -> Bool {
  let range = request.headers.get("Range")
  let request_method = oracle_request_name(request)
  let upload = request.path == "/transfer-stdin-retry" ||
    request.path == "/transfer-stdin-redirect" ||
    request.path == "/transfer-stdin-replayed"
  let body = if upload {
    if request.headers
      .get("Expect")
      .unwrap_or("")
      .to_lower()
      .contains("100-continue") {
      connection..send_response(100, "Continue").end_response()
    }
    connection.read_all().binary()
  } else {
    b""
  }
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
    transfer_fixture_response(request.path, range, request_method~)
  }
  guard response is Some(response) else { return false }
  if requests is Some(requests) {
    requests.push({ request_method, path: request.path, range, body, })
  }
  connection.enter_passthrough_mode()
  defer connection.close()
  if response != "" {
    connection.write(response)
  }
  true
}
