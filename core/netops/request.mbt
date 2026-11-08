///|
fn validate_transfer_options(
  options : TransferOptions,
) -> Unit raise TransferError {
  if options.connect_timeout_ms <= 0 || options.idle_timeout_ms <= 0 {
    raise transfer_error(TimeoutFailure, "timeouts must be greater than zero")
  }
  if options.max_time_ms is Some(value) && value <= 0 {
    raise transfer_error(
      TimeoutFailure,
      "maximum transfer time must be greater than zero",
    )
  }
  if options.resume_from is Some(offset) && offset < 0L {
    raise transfer_error(ProtocolFailure, "resume offset must not be negative")
  }
  match options.redirects {
    FollowRedirects(limit) if limit < 0 =>
      raise transfer_error(
        RedirectFailure,
        "redirect limit must not be negative",
      )
    _ => ()
  }
}

///|
fn validate_headers(
  headers : ArrayView[HttpHeader],
) -> Unit raise TransferError {
  for header in headers {
    if !wire_token(header.name) ||
      header.value.contains("\r") ||
      header.value.contains("\n") {
      raise transfer_error(
        ProtocolFailure,
        "invalid HTTP header '\{header.name}'",
      )
    }
    let name = header.name.to_lower()
    if name == "host" || name == "transfer-encoding" {
      raise transfer_error(
        ProtocolFailure,
        "HTTP header '\{header.name}' is managed by the transport",
      )
    }
  }
}

///|
priv struct PreparedHeaders {
  persistent : HeaderFields
  per_request : HeaderFields
  authorization_supplied : Bool
}

///|
priv struct HeaderFields {
  fields : Array[HttpHeader]
}

///|
fn HeaderFields::get(self : HeaderFields, name : String) -> String? {
  let name = name.to_lower()
  for header in self.fields {
    if header.name.to_lower() == name {
      return Some(header.value)
    }
  }
  None
}

///|
fn HeaderFields::contains(self : HeaderFields, name : String) -> Bool {
  self.get(name) is Some(_)
}

///|
fn HeaderFields::set(
  self : HeaderFields,
  name : String,
  value : String,
) -> Unit {
  let lower = name.to_lower()
  for index in 0..<self.fields.length() {
    if self.fields[index].name.to_lower() == lower {
      self.fields[index] = http_header(self.fields[index].name, value)
      return
    }
  }
  self.fields.push(http_header(name, value))
}

///|
fn uses_basic_authentication(value : String) -> Bool {
  let value = value.to_lower().trim_start()
  value == "basic" || value.has_prefix("basic ") || value.has_prefix("basic\t")
}

///|
fn has_basic_challenge(value : String) -> Bool {
  let mut part = StringBuilder()
  let mut quoted = false
  let mut escaped = false
  for character in value {
    if quoted {
      part.write_char(character)
      if escaped {
        escaped = false
      } else if character == '\\' {
        escaped = true
      } else if character == '"' {
        quoted = false
      }
    } else if character == ',' {
      if basic_challenge_part(part.to_string()) {
        return true
      }
      part = StringBuilder()
    } else {
      part.write_char(character)
      if character == '"' {
        quoted = true
      }
    }
  }
  !quoted && basic_challenge_part(part.to_string())
}

///|
fn basic_challenge_part(value : String) -> Bool {
  let value = value.trim().to_owned()
  uses_basic_authentication(value) && !value[5:].trim_start().has_prefix("=")
}

///|
async fn body_length(body : RequestBody) -> Int64? {
  match body {
    EmptyBody => None
    BytesBody(data) => Some(data.length().to_int64())
    FileBody(path) => {
      let file = @fs.open(path, mode=ReadOnly) catch {
        err =>
          raise transfer_error(
            InputFailure,
            "cannot open request body '\{path}': \{err}",
          )
      }
      defer file.close()
      Some(file.size()) catch {
        err =>
          raise transfer_error(
            InputFailure,
            "cannot determine request body size '\{path}': \{err}",
          )
      }
    }
    StdinBody => None
  }
}

///|
fn request_headers(
  parsed : ParsedUrl,
  headers : ArrayView[HttpHeader],
  length : Int64?,
  resume_from : Int64?,
  profile : TransferProfile,
) -> PreparedHeaders {
  let persistent : HeaderFields = { fields: [], }
  let per_request : HeaderFields = { fields: [], }
  for header in headers {
    if profile == CurlProfile {
      per_request.fields.push(header)
    } else if header.name.to_lower() == "user-agent" {
      persistent.set(header.name, header.value)
    } else {
      per_request.set(header.name, header.value)
    }
  }
  let authorization_supplied = per_request.contains("Authorization")
  if profile != WgetProfile &&
    !authorization_supplied &&
    parsed.user_info is Some(user_info) {
    per_request.set(
      "Authorization",
      "Basic " + @base64.encode(@utf8.encode(percent_decode(user_info))),
    )
  }
  if length is Some(value) && !per_request.contains("Content-Length") {
    per_request.set("Content-Length", value.to_string())
  }
  if !per_request.contains("Accept-Encoding") {
    // Keep transfer counts and Range offsets on the encoded representation.
    per_request.set("Accept-Encoding", "identity")
  }
  if resume_from is Some(value) && value > 0L && !per_request.contains("Range") {
    per_request.set("Range", "bytes=\{value}-")
  }
  { persistent, per_request, authorization_supplied, }
}

///|
async fn open_client(
  parsed : ParsedUrl,
  options : TransferOptions,
  started : Int64,
) -> HttpWire {
  let mut created : Connection? = None
  let timeout = timeout_for(
    options,
    started,
    options.connect_timeout_ms,
    "connection setup",
  )
  let result = @async.with_timeout_opt(timeout, () => {
    let proxy = match options.proxy_url {
      None => None
      Some(proxy_url) => {
        let proxy = parse_absolute_url(proxy_url).for_transfer(
          options.profile,
          utf8_hosts=options.utf8_hosts,
        ) catch {
          TransferError(message~, ..) =>
            raise transfer_error(ProxyFailure, message)
        }
        Some(proxy)
      }
    }
    let client = connect_endpoint(
      parsed,
      proxy,
      if options.verify_tls {
        @tls.SystemRoot
      } else {
        @tls.NoVerification
      },
    )
    created = Some(client)
    HttpWire::new(client)
  }) catch {
    @tls.TlsError(message) => raise transfer_error(TlsFailure, message)
    TransferError(..) as error => raise error
    err =>
      raise transfer_error(
        ConnectionFailure,
        "connection to \{parsed.origin()} failed: \{err}",
      )
  }
  match result {
    Some(client) => client
    None => {
      match created {
        Some(client) => client.close()
        None => ()
      }
      raise timeout_error("connection setup", timeout)
    }
  }
}

///|
async fn stream_file_body(
  client : HttpWire,
  path : String,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  let file = @fs.open(path, mode=ReadOnly) catch {
    err =>
      raise transfer_error(
        InputFailure,
        "cannot open request body '\{path}': \{err}",
      )
  }
  defer file.close()
  for ;; {
    let timeout = timeout_for(
      options,
      started,
      options.idle_timeout_ms,
      "request body input",
    )
    let result = @async.with_timeout_opt(timeout, () => {
      file.read_some(max_len=65536)
    }) catch {
      err =>
        raise transfer_error(InputFailure, "request body read failed: \{err}")
    }
    let chunk = match result {
      Some(Some(chunk)) => chunk
      Some(None) => break
      None => raise timeout_error("request body input", timeout)
    }
    client.write_payload(chunk, options, started)
  }
}

///|
async fn stream_stdin_body(
  client : HttpWire,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  for ;; {
    let timeout = timeout_for(
      options,
      started,
      options.idle_timeout_ms,
      "request body input",
    )
    let result = @async.with_timeout_opt(timeout, () => {
      @stdio.stdin.read_some(max_len=65536)
    }) catch {
      err =>
        raise transfer_error(InputFailure, "standard input read failed: \{err}")
    }
    let chunk = match result {
      Some(Some(chunk)) => chunk
      Some(None) => break
      None => raise timeout_error("request body input", timeout)
    }
    client.write_payload(chunk, options, started)
  }
}

///|
async fn send_request(
  client : HttpWire,
  parsed : ParsedUrl,
  request_method : HttpMethod,
  persistent : HeaderFields,
  headers : HeaderFields,
  body : RequestBody,
  options : TransferOptions,
  started : Int64,
) -> Response {
  client.start_request(
    parsed, request_method, persistent, headers, body, options, started,
  )
  match body {
    EmptyBody => ()
    BytesBody(data) => client.write_payload(data, options, started)
    FileBody(path) => stream_file_body(client, path, options, started)
    StdinBody => stream_stdin_body(client, options, started)
  }
  client.finish_request(options, started)
  let timeout = timeout_for(
    options,
    started,
    options.idle_timeout_ms,
    "response headers",
  ) catch {
    error => raise with_failure_context(error, failure_context(ResponseHeaders))
  }
  let response_result = @async.with_timeout_opt(timeout, () => {
    client.response(request_method, profile=options.profile)
  }) catch {
    @io.ReaderClosed =>
      raise transfer_error(
        if client.header_bytes == 0L {
          EmptyReplyFailure
        } else {
          ReceiveFailure
        },
        if client.header_bytes == 0L {
          "server returned an empty reply"
        } else {
          "response headers ended before completion"
        },
        context=failure_context(ResponseHeaders),
      )
    TransferError(..) as error =>
      raise with_failure_context(error, failure_context(ResponseHeaders))
    error =>
      raise transfer_error(
        ReceiveFailure,
        "response header read failed: \{error}",
        context=failure_context(ResponseHeaders),
      )
  }
  match response_result {
    Some(response) => response
    None =>
      raise with_failure_context(
        timeout_error("response headers", timeout),
        failure_context(ResponseHeaders),
      )
  }
}
