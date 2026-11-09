///|
async fn open_transport(target : ParsedUrl, transport : Transport) -> HttpWire {
  let mut created : Connection? = None
  let timeout = transport.timeout(
    transport.connect_timeout_ms,
    "connection setup",
  )
  let result = @async.with_timeout_opt(timeout, () => {
    let connection = connect_endpoint(
      target,
      transport.proxy,
      if transport.verify_tls {
        @tls.SystemRoot
      } else {
        @tls.NoVerification
      },
    )
    created = Some(connection)
    HttpWire::new(connection)
  }) catch {
    @tls.TlsError(message) => raise transfer_error(TlsFailure, message)
    TransferError(..) as error => raise error
    error =>
      raise transfer_error(
        ConnectionFailure,
        "connection to \{target.origin()} failed: \{error}",
      )
  }
  match result {
    Some(wire) => wire
    None => {
      if created is Some(connection) {
        connection.close()
      }
      raise timeout_error("connection setup", timeout)
    }
  }
}

///|
async fn HttpWire::write_transport(
  self : HttpWire,
  bytes : Bytes,
  transport : Transport,
) -> Unit {
  let timeout = transport.timeout(transport.idle_timeout_ms, "request")
  let result = @async.with_timeout_opt(timeout, () => self.client.write(bytes)) catch {
    error =>
      raise transfer_error(ConnectionFailure, "request write failed: \{error}")
  }
  if result is None {
    raise timeout_error("request", timeout)
  }
}

///|
async fn HttpWire::start_exchange(
  self : HttpWire,
  request : Request,
  transport : Transport,
) -> Unit {
  let fields = request.headers
  validate_headers(fields)
  guard fields
    .filter(field => field.name.to_lower() == "content-length")
    .length() <=
    1 else {
    raise transfer_error(InputFailure, "multiple request Content-Length fields")
  }
  let headers : HeaderFields = { fields, }
  self.request_remaining = match headers.get("Content-Length") {
    None => None
    Some(value) =>
      Some(wire_content_length(value.trim().to_owned())) catch {
        _ =>
          raise transfer_error(InputFailure, "invalid request Content-Length")
      }
  }
  self.request_chunked = self.request_remaining is None &&
    !(request.body is EmptyBody)
  let text = StringBuilder()
  text.write_string(
    request.request_method.wire_name() +
    " " +
    request.target.request_target() +
    " HTTP/1.1\r\n",
  )
  text.write_string("Host: " + request.host + "\r\n")
  if !headers.contains("User-Agent") {
    text.write_string("User-Agent: moonbit-http-client/1.1\r\n")
  }
  for field in fields {
    text.write_string(field.name + ": " + field.value + "\r\n")
  }
  if self.request_chunked {
    text.write_string("Transfer-Encoding: chunked\r\n")
  }
  text.write_string("\r\n")
  self.write_transport(@utf8.encode(text.to_string()), transport)
}

///|
async fn HttpWire::write_exchange_payload(
  self : HttpWire,
  bytes : Bytes,
  transport : Transport,
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
    self.write_transport(framed.to_bytes(), transport)
  } else {
    self.write_transport(bytes, transport)
  }
  self.request_payload_bytes += bytes.length().to_int64()
}

///|
async fn HttpWire::write_exchange_body(
  self : HttpWire,
  body : RequestBody,
  transport : Transport,
) -> Unit {
  match body {
    EmptyBody => ()
    BytesBody(bytes) => self.write_exchange_payload(bytes, transport)
    FileBody(path) => {
      let file = @fs.open(path, mode=ReadOnly) catch {
        error =>
          raise transfer_error(
            InputFailure,
            "cannot open request body '\{path}': \{error}",
          )
      }
      defer file.close()
      for ;; {
        let timeout = transport.timeout(
          transport.idle_timeout_ms,
          "request body input",
        )
        let result = @async.with_timeout_opt(timeout, () => {
          file.read_some(max_len=65536)
        }) catch {
          error =>
            raise transfer_error(
              InputFailure,
              "request body read failed: \{error}",
            )
        }
        match result {
          Some(Some(bytes)) => self.write_exchange_payload(bytes, transport)
          Some(None) => break
          None => raise timeout_error("request body input", timeout)
        }
      }
    }
    StdinBody =>
      for ;; {
        let timeout = transport.timeout(
          transport.idle_timeout_ms,
          "request body input",
        )
        let result = @async.with_timeout_opt(timeout, () => {
          @stdio.stdin.read_some(max_len=65536)
        }) catch {
          error =>
            raise transfer_error(
              InputFailure,
              "standard input read failed: \{error}",
            )
        }
        match result {
          Some(Some(bytes)) => self.write_exchange_payload(bytes, transport)
          Some(None) => break
          None => raise timeout_error("request body input", timeout)
        }
      }
  }
  if self.request_remaining is Some(remaining) && remaining != 0L {
    raise transfer_error(
      InputFailure,
      "request body is shorter than Content-Length",
    )
  }
  if self.request_chunked {
    self.write_transport(b"0\r\n\r\n", transport)
  }
}

///|
async fn exchange_request(
  wire : HttpWire,
  request : Request,
  transport : Transport,
) -> ResponseHead {
  try {
    wire.start_exchange(request, transport)
    wire.write_exchange_body(request.body, transport)
  } catch {
    TransferError(..) as error =>
      raise with_failure_context(
        error,
        failure_context(Request, sent_bytes=wire.request_payload_bytes),
      )
    error =>
      raise transfer_error(
        ConnectionFailure,
        "HTTP request failed: \{error}",
        context=failure_context(Request, sent_bytes=wire.request_payload_bytes),
      )
  }
  let timeout = transport.timeout(transport.idle_timeout_ms, "response headers") catch {
    error =>
      raise with_failure_context(
        error,
        failure_context(ResponseHeaders, sent_bytes=wire.request_payload_bytes),
      )
  }
  let result = @async.with_timeout_opt(timeout, () => {
    wire.response(request.request_method, capture_header_eof=true)
  }) catch {
    @io.ReaderClosed =>
      raise transfer_error(
        if wire.header_bytes == 0L {
          EmptyReplyFailure
        } else {
          ReceiveFailure
        },
        if wire.header_bytes == 0L {
          "server returned an empty reply"
        } else {
          "response headers ended before completion"
        },
        context=failure_context(
          ResponseHeaders,
          sent_bytes=wire.request_payload_bytes,
        ),
      )
    TransferError(..) as error =>
      raise with_failure_context(
        error,
        failure_context(ResponseHeaders, sent_bytes=wire.request_payload_bytes),
      )
    error =>
      raise transfer_error(
        ReceiveFailure,
        "response header read failed: \{error}",
        context=failure_context(
          ResponseHeaders,
          sent_bytes=wire.request_payload_bytes,
        ),
      )
  }
  match result {
    Some(response) => response
    None =>
      raise with_failure_context(
        timeout_error("response headers", timeout),
        failure_context(ResponseHeaders, sent_bytes=wire.request_payload_bytes),
      )
  }
}
