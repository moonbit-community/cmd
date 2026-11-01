///|
fn response_content_length(response : @http.Response) -> Int64? {
  if response.headers.get("Transfer-Encoding") is Some(encoding) &&
    encoding.to_lower() == "chunked" {
    return None
  }
  match response.headers.get("Content-Length") {
    Some(value) => {
      let length = @string.parse_int64(value) catch { _ => return None }
      if length >= 0L {
        Some(length)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn response_framing(
  response : @http.Response,
  request_method : HttpMethod,
) -> ResponseFraming {
  if !response_has_body(response.code, request_method) {
    return Bodyless
  }
  if response.headers.get("Transfer-Encoding") is Some(encoding) &&
    encoding.to_lower() == "chunked" {
    return Chunked
  }
  match response_content_length(response) {
    Some(length) => FixedLength(length)
    None => CloseDelimited
  }
}

///|
fn response_body_eof(
  response : @http.Response,
  request_method : HttpMethod,
  received : Int64,
) -> TransferError {
  if response_has_body(response.code, request_method) {
    if response.headers.get("Transfer-Encoding") is Some(encoding) &&
      encoding.to_lower() == "chunked" {
      return transfer_error(
        PartialBodyFailure,
        "chunked response body ended after \{received} bytes before its terminator",
      )
    }
    if response_content_length(response) is Some(expected) {
      return transfer_error(
        PartialBodyFailure,
        "response body ended after \{received} of \{expected} bytes",
      )
    }
  }
  transfer_error(ReceiveFailure, "response body read failed: unexpected EOF")
}

///|
fn resumed_response_range(
  response : @http.Response,
  resume_from : Int64?,
) -> (Int64, Int64?) raise TransferError {
  guard resume_from is Some(offset) && offset > 0L && response.code == 206 else {
    return (0L, None)
  }
  guard response.headers.get("Content-Range") is Some(value) &&
    value.has_prefix("bytes ") else {
    raise transfer_error(
      ProtocolFailure,
      "resumed response has no byte Content-Range",
    )
  }
  let range = value[6:]
  guard range.find("-") is Some(dash) &&
    range.find("/") is Some(slash) &&
    dash > 0 &&
    slash > dash + 1 else {
    raise transfer_error(ProtocolFailure, "invalid resumed Content-Range")
  }
  let start = @string.parse_int64(range[:dash]) catch {
    _ => raise transfer_error(ProtocolFailure, "invalid resumed range start")
  }
  let end = @string.parse_int64(range[dash + 1:slash]) catch {
    _ => raise transfer_error(ProtocolFailure, "invalid resumed range end")
  }
  guard start == offset && end >= start else {
    raise transfer_error(
      ProtocolFailure,
      "resumed response starts at the wrong offset",
    )
  }
  let total = range[slash + 1:]
  if total != "*" {
    let total = @string.parse_int64(total) catch {
      _ => raise transfer_error(ProtocolFailure, "invalid resumed range length")
    }
    guard total > end else {
      raise transfer_error(
        ProtocolFailure,
        "resumed range exceeds the resource length",
      )
    }
  }
  if response_content_length(response) is Some(length) &&
    length != end - start + 1L {
    raise transfer_error(
      ProtocolFailure,
      "resumed range and Content-Length disagree",
    )
  }
  (offset, Some(end - start + 1L))
}

///|
fn response_headers(
  response : @http.Response,
  cookie_fields : Array[HttpHeader],
) -> Array[HttpHeader] {
  let result : Array[HttpHeader] = []
  for name, value in response.headers {
    result.push({ name: name.to_string(), value, })
  }
  result.append(cookie_fields)
  result
}

///|
fn content_disposition_filename(value : String) -> String? {
  let mut regular : String? = None
  for part in value.split(";") {
    let item = part.trim().to_owned()
    let lower = item.to_lower()
    if lower.has_prefix("filename*=") {
      let raw = item[10:].trim().to_owned()
      let encoded = match raw.find("''") {
        Some(index) => raw[index + 2:].to_owned()
        None => raw
      }
      return Some(percent_decode(encoded))
    }
    if lower.has_prefix("filename=") {
      let raw = item[9:].trim().to_owned()
      regular = Some(
        if raw.length() >= 2 && raw.has_prefix("\"") && raw.has_suffix("\"") {
          raw[1:raw.length() - 1].to_owned()
        } else {
          raw
        },
      )
    }
  }
  regular
}

///|
fn response_has_body(code : Int32, request_method : HttpMethod) -> Bool {
  if request_method == Head ||
    (code >= 100 && code < 200) ||
    code == 204 ||
    code == 205 ||
    code == 304 {
    return false
  }
  !(request_method == Connect && code >= 200 && code < 300)
}
