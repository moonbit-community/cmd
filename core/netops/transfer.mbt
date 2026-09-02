///|
fn transfer_error(
  kind : TransferErrorKind,
  message : String,
  status? : Int,
) -> TransferError {
  TransferError(kind~, message~, status~)
}

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
fn timeout_for(
  options : TransferOptions,
  started : Int64,
  phase_timeout : Int,
  phase : String,
) -> Int raise TransferError {
  match options.max_time_ms {
    None => phase_timeout
    Some(maximum) => {
      let remaining = maximum.to_int64() - (@async.now() - started)
      if remaining <= 0L {
        raise transfer_error(
          TimeoutFailure,
          "operation timed out during \{phase}",
        )
      }
      phase_timeout.min(remaining.min(2147483647L).to_int())
    }
  }
}

///|
fn timeout_message(phase : String, timeout : Int) -> TransferError {
  transfer_error(
    TimeoutFailure,
    "operation timed out after \{timeout} milliseconds during \{phase}",
  )
}

///|
fn validate_headers(
  headers : ArrayView[HttpHeader],
) -> Unit raise TransferError {
  for header in headers {
    if header.name == "" ||
      header.name.contains(":") ||
      header.name.contains("\r") ||
      header.name.contains("\n") ||
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
fn contains_header(headers : ArrayView[HttpHeader], name : String) -> Bool {
  let name = name.to_lower()
  for header in headers {
    if header.name.to_lower() == name {
      return true
    }
  }
  false
}

///|
fn filtered_headers(
  headers : ArrayView[HttpHeader],
  strip_sensitive : Bool,
  strip_entity : Bool,
) -> Array[HttpHeader] {
  let result : Array[HttpHeader] = []
  for header in headers {
    let name = header.name.to_lower()
    if strip_sensitive &&
      (
        name == "authorization" ||
        name == "proxy-authorization" ||
        name == "cookie"
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
fn request_header_maps(
  parsed : ParsedUrl,
  headers : ArrayView[HttpHeader],
  length : Int64?,
  resume_from : Int64?,
) -> (
  Map[@http.CaseInsensitiveString, String],
  Map[@http.CaseInsensitiveString, String],
) {
  let persistent : Map[@http.CaseInsensitiveString, String] = Map([])
  let per_request : Map[@http.CaseInsensitiveString, String] = Map([])
  for header in headers {
    if header.name.to_lower() == "user-agent" {
      persistent[header.name] = header.value
    } else {
      per_request[header.name] = header.value
    }
  }
  if !contains_header(headers, "authorization") &&
    parsed.user_info is Some(user_info) {
    per_request["Authorization"] = "Basic " +
      @base64.encode(@utf8.encode(percent_decode(user_info)))
  }
  if length is Some(value) && !contains_header(headers, "content-length") {
    per_request["Content-Length"] = value.to_string()
  }
  if resume_from is Some(value) &&
    value > 0L &&
    !contains_header(headers, "range") {
    per_request["Range"] = "bytes=\{value}-"
  }
  (persistent, per_request)
}

///|
async fn open_client(
  parsed : ParsedUrl,
  headers : Map[@http.CaseInsensitiveString, String],
  options : TransferOptions,
  started : Int64,
) -> @http.Client {
  let mut created : @http.Client? = None
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
        let proxy = parse_absolute_url(proxy_url) catch {
          TransferError(message~, ..) =>
            raise transfer_error(ProxyFailure, message)
        }
        Some(
          @http.Client(
            proxy.origin(),
            trust=if options.verify_tls {
              @tls.SystemRoot
            } else {
              @tls.NoVerification
            },
          ),
        )
      }
    }
    let client = @http.Client(
      parsed.origin(),
      headers~,
      proxy?,
      trust=if options.verify_tls {
        @tls.SystemRoot
      } else {
        @tls.NoVerification
      },
    )
    created = Some(client)
    client
  }) catch {
    @tls.TlsError(message) => raise transfer_error(TlsFailure, message)
    @http.ProxyError(_) =>
      raise transfer_error(ProxyFailure, "proxy connection failed")
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
      raise timeout_message("connection setup", timeout)
    }
  }
}

///|
async fn write_client_chunk(
  client : @http.Client,
  chunk : Bytes,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  let timeout = timeout_for(
    options,
    started,
    options.idle_timeout_ms,
    "request body",
  )
  let result = @async.with_timeout_opt(timeout, () => client.write(chunk)) catch {
    err =>
      raise transfer_error(
        ConnectionFailure,
        "request body write failed: \{err}",
      )
  }
  match result {
    Some(_) => ()
    None => raise timeout_message("request body", timeout)
  }
}

///|
async fn stream_file_body(
  client : @http.Client,
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
      None => raise timeout_message("request body input", timeout)
    }
    write_client_chunk(client, chunk, options, started)
  }
}

///|
async fn stream_stdin_body(
  client : @http.Client,
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
      None => raise timeout_message("request body input", timeout)
    }
    write_client_chunk(client, chunk, options, started)
  }
}

///|
async fn send_request(
  client : @http.Client,
  parsed : ParsedUrl,
  request_method : HttpMethod,
  headers : Map[@http.CaseInsensitiveString, String],
  body : RequestBody,
  options : TransferOptions,
  started : Int64,
) -> @http.Response {
  let timeout = timeout_for(
    options,
    started,
    options.idle_timeout_ms,
    "request headers",
  )
  let request_result = @async.with_timeout_opt(timeout, () => {
    client.request(
      request_method.to_runtime(),
      parsed.request_target(),
      extra_headers=headers,
    )
  }) catch {
    err =>
      raise transfer_error(
        ConnectionFailure,
        "request header write failed: \{err}",
      )
  }
  match request_result {
    Some(_) => ()
    None => raise timeout_message("request headers", timeout)
  }
  match body {
    EmptyBody => ()
    BytesBody(data) => write_client_chunk(client, data, options, started)
    FileBody(path) => stream_file_body(client, path, options, started)
    StdinBody => stream_stdin_body(client, options, started)
  }
  let timeout = timeout_for(
    options,
    started,
    options.idle_timeout_ms,
    "response headers",
  )
  let response_result = @async.with_timeout_opt(timeout, () => {
    client.end_request()
  }) catch {
    err =>
      raise transfer_error(
        ConnectionFailure,
        "response header read failed: \{err}",
      )
  }
  match response_result {
    Some(response) => response
    None => raise timeout_message("response headers", timeout)
  }
}

///|
fn response_content_length(response : @http.Response) -> Int64? {
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
fn response_headers(response : @http.Response) -> Array[HttpHeader] {
  let result : Array[HttpHeader] = []
  for name, value in response.headers {
    result.push({ name: name.to_string(), value, })
  }
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
fn output_path(output : TransferOutput, response : @http.Response) -> String? {
  match output {
    FileOutput(path~, content_disposition=true, ..) =>
      match response.headers.get("Content-Disposition") {
        Some(value) =>
          match content_disposition_filename(value) {
            Some(name) => Some(@fsops.basename(name))
            None => Some(path)
          }
        None => Some(path)
      }
    FileOutput(path~, ..) => Some(path)
    StandardOutput | DiscardOutput => None
  }
}

///|
priv enum OutputSink {
  StdoutSink
  DiscardSink
  FileSink(String, @fs.File, Bool)
}

///|
async fn open_sink(
  output : TransferOutput,
  response : @http.Response,
) -> OutputSink {
  match output {
    StandardOutput => StdoutSink
    DiscardOutput => DiscardSink
    FileOutput(mode~, remove_on_error~, ..) => {
      let path = output_path(output, response).unwrap()
      let opened = try {
        match mode {
          Truncate => (path, @fsops.open_output(path, CreateOrTruncate))
          Append => (path, @fsops.open_output(path, AppendOrCreate))
          Unique => @fsops.open_unique_numbered_output(path)
        }
      } catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot open output '\{path}': \{err}",
          )
      }
      FileSink(opened.0, opened.1, remove_on_error)
    }
  }
}

///|
fn OutputSink::path(self : OutputSink) -> String? {
  match self {
    FileSink(path, _, _) => Some(path)
    StdoutSink | DiscardSink => None
  }
}

///|
fn OutputSink::close(self : OutputSink) -> Unit {
  match self {
    FileSink(_, file, _) => file.close()
    StdoutSink | DiscardSink => ()
  }
}

///|
async fn OutputSink::write(self : OutputSink, chunk : Bytes) -> Unit {
  match self {
    StdoutSink => @stdio.stdout.write(chunk)
    DiscardSink => ()
    FileSink(path, file, _) =>
      file.write(chunk) catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot write output '\{path}': \{err}",
          )
      }
  }
}

///|
async fn OutputSink::cleanup_after_error(self : OutputSink) -> Unit {
  match self {
    FileSink(path, _, true) => @fsops.cleanup_file_if_exists(path)
    FileSink(_, _, false) | StdoutSink | DiscardSink => ()
  }
}

///|
async fn emit(
  observer : (async (TransferEvent) -> Unit)?,
  event : TransferEvent,
) -> Unit {
  match observer {
    Some(callback) => callback(event)
    None => ()
  }
}

///|
fn is_redirect(code : Int) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
}

///|
fn response_has_body(code : Int, request_method : HttpMethod) -> Bool {
  if request_method == Head ||
    (code >= 100 && code < 200) ||
    code == 204 ||
    code == 205 ||
    code == 304 {
    return false
  }
  !(request_method == Connect && code >= 200 && code < 300)
}

///|
fn rewritten_request(
  code : Int,
  request_method : HttpMethod,
  body : RequestBody,
  preserve_method : Bool,
) -> (HttpMethod, RequestBody, Bool) {
  if preserve_method || code == 307 || code == 308 || request_method == Head {
    return (request_method, body, false)
  }
  if code == 303 || ((code == 301 || code == 302) && request_method == Post) {
    (Get, EmptyBody, true)
  } else {
    (request_method, body, false)
  }
}

///|
pub fn retryable_failure(kind : TransferErrorKind, status : Int?) -> Bool {
  match kind {
    ConnectionFailure | TimeoutFailure => true
    HttpStatusFailure =>
      match status {
        Some(408 | 429 | 500 | 502 | 503 | 504) => true
        _ => false
      }
    InvalidUrl
    | UnsupportedProtocol
    | InvalidMethod
    | TlsFailure
    | ProxyFailure
    | RedirectFailure
    | InputFailure
    | OutputFailure
    | ProtocolFailure => false
  }
}

///|
pub async fn transfer(
  url : String,
  output : TransferOutput,
  options : TransferOptions,
  observer? : async (TransferEvent) -> Unit,
) -> TransferResult {
  validate_transfer_options(options)
  validate_headers(options.headers)
  let started = @async.now()
  let requested_url = url
  let mut parsed = parse_absolute_url(url)
  let mut request_method = options.request_method
  let mut body = options.body
  let mut headers = options.headers.copy()
  let seen : Map[String, Bool] = Map([])
  let mut redirect_count = 0
  for ;; {
    let key = parsed.to_url()
    if seen.contains(key) {
      raise transfer_error(RedirectFailure, "redirect loop detected at \{key}")
    }
    seen[key] = true
    let length = body_length(body)
    let (persistent, per_request) = request_header_maps(
      parsed,
      headers,
      length,
      options.resume_from,
    )
    let client = open_client(parsed, persistent, options, started)
    errdefer client.close()
    let response = send_request(
      client, parsed, request_method, per_request, body, options, started,
    ) catch {
      TransferError(..) as err => raise err
      err =>
        raise transfer_error(ConnectionFailure, "HTTP request failed: \{err}")
    }
    let total = response_content_length(response)
    let visible_headers = response_headers(response)
    emit(
      observer,
      ResponseStarted(
        url=parsed.to_url(),
        status=response.code,
        reason=response.reason,
        headers=visible_headers,
        content_length=total,
      ),
    )
    if is_redirect(response.code) &&
      response.headers.get("Location") is Some(location) &&
      options.redirects is FollowRedirects(limit) {
      if redirect_count >= limit {
        client.close()
        raise transfer_error(
          RedirectFailure,
          "maximum redirects (\{limit}) exceeded",
          status=response.code,
        )
      }
      let next = resolve_location(parsed, location) catch {
        TransferError(message~, ..) => {
          client.close()
          raise transfer_error(
            RedirectFailure,
            "invalid redirect target: \{message}",
            status=response.code,
          )
        }
      }
      emit(
        observer,
        Redirected(status=response.code, from=parsed.to_url(), to=next.to_url()),
      )
      let cross_origin = parsed.origin_key() != next.origin_key()
      let (next_method, next_body, strip_entity) = rewritten_request(
        response.code,
        request_method,
        body,
        options.preserve_method_on_redirect,
      )
      headers = filtered_headers(headers, cross_origin, strip_entity)
      request_method = next_method
      body = next_body
      parsed = next
      redirect_count += 1
      client.close()
      continue
    }
    if (options.fail_on_http_error && response.code >= 400) ||
      options.http_error_statuses.contains(response.code) {
      client.close()
      raise transfer_error(
        HttpStatusFailure,
        "server returned HTTP status \{response.code} \{response.reason}",
        status=response.code,
      )
    }
    let effective_output = if options.keep_output_on_not_modified &&
      response.code == 304 {
      DiscardOutput
    } else {
      match (options.resume_from, response.code, output) {
        (
          Some(offset),
          200,
          FileOutput(path~, content_disposition~, remove_on_error~, ..),
        ) if offset > 0L =>
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition~,
            remove_on_error~,
          )
        _ => output
      }
    }
    let sink = open_sink(effective_output, response)
    let received = try {
      let mut count = 0L
      for ;; {
        let timeout = timeout_for(
          options,
          started,
          options.idle_timeout_ms,
          "response body",
        )
        let read_result = @async.with_timeout_opt(timeout, () => {
          client.read_some(max_len=65536)
        }) catch {
          err =>
            raise transfer_error(
              ConnectionFailure,
              "response body read failed: \{err}",
            )
        }
        let chunk = match read_result {
          Some(Some(chunk)) => chunk
          Some(None) => break
          None => raise timeout_message("response body", timeout)
        }
        sink.write(chunk)
        count += chunk.length().to_int64()
        emit(observer, Progress(received=count, content_length=total))
      }
      if response_has_body(response.code, request_method) &&
        total is Some(expected) &&
        count != expected {
        raise transfer_error(
          ConnectionFailure,
          "response body ended after \{count} of \{expected} bytes",
        )
      }
      count
    } catch {
      TransferError(..) as transfer_failure => {
        sink.close()
        sink.cleanup_after_error() catch {
          _ => ()
        }
        client.close()
        raise transfer_failure
      }
      err => {
        sink.close()
        sink.cleanup_after_error() catch {
          _ => ()
        }
        client.close()
        raise transfer_error(
          ConnectionFailure,
          "response transfer failed: \{err}",
        )
      }
    }
    sink.close()
    client.close()
    emit(observer, Completed(received~, content_length=total))
    return {
      requested_url,
      effective_url: parsed.to_url(),
      status: response.code,
      reason: response.reason,
      headers: visible_headers,
      received,
      output_path: sink.path(),
      redirects: redirect_count,
    }
  }
}
