///|
fn filtered_headers(
  headers : ArrayView[HttpHeader],
  strip_sensitive : Bool,
  strip_entity : Bool,
  keep_cookie~ : Bool = false,
) -> Array[HttpHeader] {
  let result : Array[HttpHeader] = []
  for header in headers {
    let name = header.name.to_lower()
    if strip_sensitive &&
      (
        name == "authorization" ||
        name == "proxy-authorization" ||
        (name == "cookie" && !keep_cookie)
      ) {
      continue
    }
    if strip_entity && (name == "content-length" || name == "content-type") {
      continue
    }
    result.push(header)
  }
  result
}

///|
fn is_redirect(code : Int32) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
}

///|
fn rewritten_request(
  code : Int32,
  request_method : HttpMethod,
  body : RequestBody,
  preserve_method : Bool,
) -> (HttpMethod, RequestBody, Bool) {
  if code == 307 || code == 308 || request_method == Head {
    return (request_method, body, false)
  }
  if preserve_method {
    return match body {
      EmptyBody => (request_method, body, false)
      FileBody(_) | StdinBody => (request_method, body, false)
      BytesBody(_) => (request_method, EmptyBody, true)
    }
  }
  if code == 303 || ((code == 301 || code == 302) && request_method == Post) {
    (Get, EmptyBody, true)
  } else {
    (request_method, body, false)
  }
}

///|
fn require_replayable_redirect(
  profile : TransferProfile,
  body : RequestBody,
  sent : Int64,
) -> Unit raise TransferError {
  if profile == CurlProfile && body is StdinBody && sent > 0L {
    raise transfer_error(
      RewindFailure,
      "cannot rewind standard input for the redirected request",
      context=failure_context(Request),
    )
  }
}
