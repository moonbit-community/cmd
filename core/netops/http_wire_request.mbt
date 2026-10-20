///|
fn HttpMethod::wire_name(self : HttpMethod) -> String {
  match self {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
fn wire_hex(length : Int32) -> String {
  if length < 16 {
    return "0123456789abcdef"[length:length + 1].to_owned()
  }
  wire_hex(length / 16) + wire_hex(length % 16)
}

///|
async fn HttpWire::write_raw(
  self : HttpWire,
  bytes : Bytes,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  let timeout = timeout_for(
    options,
    started,
    options.idle_timeout_ms,
    "request",
  )
  let result = @async.with_timeout_opt(timeout, () => self.client.write(bytes)) catch {
    error =>
      raise transfer_error(ConnectionFailure, "request write failed: \{error}")
  }
  if result is None {
    raise timeout_message("request", timeout)
  }
}

///|
async fn HttpWire::start_request(
  self : HttpWire,
  parsed : ParsedUrl,
  request_method : HttpMethod,
  persistent : Map[@http.CaseInsensitiveString, String],
  headers : Map[@http.CaseInsensitiveString, String],
  body : RequestBody,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  let fields : Array[HttpHeader] = []
  for name, value in persistent {
    fields.push(http_header(name.to_string(), value))
  }
  for name, value in headers {
    fields.push(http_header(name.to_string(), value))
  }
  validate_headers(fields)
  self.request_remaining = match headers.get("Content-Length") {
    None => None
    Some(value) =>
      Some(wire_content_length(value.trim().to_owned())) catch {
        _ =>
          raise transfer_error(InputFailure, "invalid request Content-Length")
      }
  }
  self.request_chunked = self.request_remaining is None && !(body is EmptyBody)
  let text = StringBuilder()
  text.write_string(
    request_method.wire_name() + " " + parsed.request_target() + " HTTP/1.1\r\n",
  )
  text.write_string("Host: " + parsed.endpoint + "\r\n")
  if !persistent.contains("User-Agent") {
    text.write_string("User-Agent: moonbit-http-client/1.1\r\n")
  }
  for name, value in persistent {
    text.write_string(name.to_string() + ": " + value + "\r\n")
  }
  for name, value in headers {
    text.write_string(name.to_string() + ": " + value + "\r\n")
  }
  if self.request_chunked {
    text.write_string("Transfer-Encoding: chunked\r\n")
  }
  text.write_string("\r\n")
  self.write_raw(@utf8.encode(text.to_string()), options, started)
}

///|
async fn HttpWire::write_payload(
  self : HttpWire,
  bytes : Bytes,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  if bytes.is_empty() {
    return
  }
  if self.request_remaining is Some(remaining) {
    guard bytes.length().to_int64() <= remaining else {
      raise transfer_error(InputFailure, "request body exceeds Content-Length")
    }
    self.request_remaining = Some(remaining - bytes.length().to_int64())
  }
  if self.request_chunked {
    let framed = Buffer()
    framed.write_bytes(@utf8.encode(wire_hex(bytes.length()) + "\r\n"))
    framed.write_bytes(bytes)
    framed.write_bytes(b"\r\n")
    self.write_raw(framed.to_bytes(), options, started)
  } else {
    self.write_raw(bytes, options, started)
  }
  self.request_payload_bytes += bytes.length().to_int64()
}

///|
async fn HttpWire::finish_request(
  self : HttpWire,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  if self.request_remaining is Some(remaining) && remaining != 0L {
    raise transfer_error(
      InputFailure,
      "request body is shorter than Content-Length",
    )
  }
  if self.request_chunked {
    self.write_raw(b"0\r\n\r\n", options, started)
  }
}
