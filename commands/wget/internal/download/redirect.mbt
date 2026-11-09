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
) -> (HttpMethod, RequestBody, Bool) {
  if code == 307 || code == 308 || request_method == Head {
    return (request_method, body, false)
  }
  if code == 303 || ((code == 301 || code == 302) && request_method == Post) {
    (Get, EmptyBody, true)
  } else {
    (request_method, body, false)
  }
}
