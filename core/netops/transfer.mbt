///|
fn transfer_error(
  kind : TransferErrorKind,
  message : String,
  status? : Int32,
  context? : TransferFailureContext,
) -> TransferError {
  TransferError(kind~, message~, status~, context~)
}

///|
fn failure_context(
  phase : TransferPhase,
  framing? : ResponseFraming,
  received_bytes~ : Int64 = 0L,
  committed_bytes~ : Int64 = 0L,
  write_outcome_uncertain~ : Bool = false,
) -> TransferFailureContext {
  { phase, framing, received_bytes, committed_bytes, write_outcome_uncertain, }
}

///|
fn with_failure_context(
  error : TransferError,
  fallback : TransferFailureContext,
) -> TransferError {
  let TransferError(kind~, message~, status~, context~) = error
  TransferError(
    kind~,
    message~,
    status~,
    context=Some(context.unwrap_or(fallback)),
  )
}

///|
fn response_body_failure(
  error : TransferError,
  framing : ResponseFraming,
  received_bytes~ : Int64,
  committed_bytes~ : Int64,
  write_outcome_uncertain? : Bool,
) -> TransferError {
  let TransferError(kind~, ..) = error
  with_failure_context(
    error,
    failure_context(
      ResponseBody,
      framing~,
      received_bytes~,
      committed_bytes~,
      write_outcome_uncertain=write_outcome_uncertain.unwrap_or(
        kind == OutputFailure,
      ),
    ),
  )
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
fn timeout_for(
  options : TransferOptions,
  started : Int64,
  phase_timeout : Int32,
  phase : String,
) -> Int32 raise TransferError {
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
fn timeout_message(phase : String, timeout : Int32) -> TransferError {
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
  if !contains_header(headers, "accept-encoding") {
    // Keep transfer counts and Range offsets on the encoded representation.
    per_request["Accept-Encoding"] = "identity"
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
  options : TransferOptions,
  started : Int64,
) -> HttpWire {
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
      proxy?,
      trust=if options.verify_tls {
        @tls.SystemRoot
      } else {
        @tls.NoVerification
      },
    )
    created = Some(client)
    HttpWire::new(client)
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
  client : HttpWire,
  chunk : Bytes,
  options : TransferOptions,
  started : Int64,
) -> Unit {
  client.write_payload(chunk, options, started)
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
      None => raise timeout_message("request body input", timeout)
    }
    write_client_chunk(client, chunk, options, started)
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
      None => raise timeout_message("request body input", timeout)
    }
    write_client_chunk(client, chunk, options, started)
  }
}

///|
async fn send_request(
  client : HttpWire,
  parsed : ParsedUrl,
  request_method : HttpMethod,
  persistent : Map[@http.CaseInsensitiveString, String],
  headers : Map[@http.CaseInsensitiveString, String],
  body : RequestBody,
  options : TransferOptions,
  started : Int64,
) -> @http.Response {
  client.start_request(
    parsed, request_method, persistent, headers, body, options, started,
  )
  match body {
    EmptyBody => ()
    BytesBody(data) => write_client_chunk(client, data, options, started)
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
        timeout_message("response headers", timeout),
        failure_context(ResponseHeaders),
      )
  }
}

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
fn response_headers(response : @http.Response) -> Array[HttpHeader] {
  let result : Array[HttpHeader] = []
  for name, value in response.headers {
    result.push({ name: name.to_string(), value, })
  }
  for cookie in response.cookies {
    let value = StringBuilder()
    value.write_string(cookie.name + "=" + cookie.value)
    if cookie.path is Some(path) {
      value.write_string("; Path=" + path)
    }
    if cookie.domain is Some(domain) {
      value.write_string("; Domain=" + domain)
    }
    if cookie.expires_raw is Some(expires) {
      value.write_string("; Expires=" + expires)
    }
    if cookie.max_age is Some(age) {
      value.write_string("; Max-Age=" + age.to_string())
    }
    if cookie.secure {
      value.write_string("; Secure")
    }
    if cookie.http_only {
      value.write_string("; HttpOnly")
    }
    for extension in cookie.extensions {
      value.write_string("; " + extension)
    }
    result.push(http_header("Set-Cookie", value.to_string()))
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
    StdoutSink =>
      @stdio.stdout.write(chunk) catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot write standard output: \{err}",
          )
      }
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
fn is_redirect(code : Int32) -> Bool {
  code == 301 || code == 302 || code == 303 || code == 307 || code == 308
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
pub fn retryable_failure(kind : TransferErrorKind, status : Int32?) -> Bool {
  match kind {
    ConnectionFailure
    | EmptyReplyFailure
    | ReceiveFailure
    | PartialBodyFailure
    | TimeoutFailure => true
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
    | RewindFailure
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
  let credential_origin = parsed.origin_key()
  let challenged_origins : Map[String, Bool] = Map([])
  let mut request_method = options.request_method
  let mut body = options.body
  let mut headers = options.headers.copy()
  let cookie_data = options.cookie_data
  let seen : Map[String, Bool] = Map([])
  let mut redirect_count = 0
  for ;; {
    let origin = parsed.origin_key()
    let credentials_allowed = options.basic_credential_scope == AllOrigins ||
      origin == credential_origin
    let send_basic = options.basic_preemptive ||
      challenged_origins.contains(origin)
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
    if credentials_allowed &&
      send_basic &&
      options.basic_credentials is Some(credentials) &&
      !contains_header(headers, "authorization") {
      per_request["Authorization"] = "Basic " +
        @base64.encode(@utf8.encode(credentials))
    }
    let stored = match options.cookie_jar {
      Some(jar) => jar.header_for(parsed, @fsops.current_timestamp().seconds)
      None => None
    }
    if per_request.contains("Cookie") &&
      stored is Some(value) &&
      options.custom_cookie_mode is SeparateFields {
      // The transport serializes persistent headers before request headers. These are two
      // independent maps, so the jar and explicit field retain their wire
      // identity and order without merging values.
      persistent["Cookie"] = value
    }
    if !per_request.contains("Cookie") {
      let literal = if parsed.origin_key() == credential_origin {
        cookie_data
      } else {
        None
      }
      let value = match (stored, literal) {
        (Some(stored), Some(literal)) => Some(stored + "; " + literal)
        (Some(stored), None) => Some(stored)
        (None, Some(literal)) => Some(literal)
        (None, None) => None
      }
      if value is Some(value) {
        per_request["Cookie"] = value
      }
    }
    let client = open_client(parsed, options, started) catch {
      TransferError(..) as error =>
        raise with_failure_context(error, failure_context(Connection))
      error => raise error
    }
    errdefer client.close()
    let response = send_request(
      client, parsed, request_method, persistent, per_request, body, options, started,
    ) catch {
      TransferError(..) as err =>
        raise with_failure_context(err, failure_context(Request))
      err =>
        raise transfer_error(
          ConnectionFailure,
          "HTTP request failed: \{err}",
          context=failure_context(Request),
        )
    }
    if options.cookie_jar is Some(jar) {
      jar.receive(parsed, response.cookies, @fsops.current_timestamp().seconds)
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
    if response.code == 401 &&
      !send_basic &&
      credentials_allowed &&
      options.basic_credentials is Some(_) &&
      response.headers.get("WWW-Authenticate") is Some(challenge) &&
      challenge.to_lower().trim_start().has_prefix("basic") {
      if body is StdinBody {
        client.close()
        raise transfer_error(
          InputFailure,
          "cannot replay standard input after an authentication challenge",
        )
      }
      challenged_origins[origin] = true
      seen.remove(key)
      client.close()
      continue
    }
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
      require_replayable_redirect(
        options.profile,
        next_body,
        client.request_payload_bytes,
      )
      headers = filtered_headers(
        headers,
        cross_origin,
        strip_entity,
        keep_cookie=options.custom_cookie_cross_origin,
      )
      request_method = next_method
      body = next_body
      parsed = next
      redirect_count += 1
      client.close()
      continue
    }
    if options.profile == WgetProfile &&
      request_method == Head &&
      response.code == 206 &&
      !per_request.contains("Range") {
      raise transfer_error(
        ReceiveFailure,
        "unexpected partial response during filename discovery",
        status=response.code,
      )
    }
    if options.profile == WgetProfile && response.code == 416 {
      client.close()
      emit(observer, Completed(received=0L, content_length=total))
      return {
        requested_url,
        effective_url: parsed.to_url(),
        status: response.code,
        reason: response.reason,
        headers: visible_headers,
        received: 0L,
        output_path: output_path(output, response),
        redirects: redirect_count,
      }
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
    let (response_offset, response_span) = resumed_response_range(
      response,
      options.resume_from,
    ) catch {
      TransferError(kind~, message~, status~, context~) as error => {
        if options.profile == WgetProfile && kind == ProtocolFailure {
          raise TransferError(kind=ReceiveFailure, message~, status~, context~)
        }
        raise error
      }
    }
    if options.resume_from is Some(offset) &&
      offset > 0L &&
      (options.resume_skip_existing || response.code == 206) {
      match output {
        FileOutput(path~, ..) if output_path(output, response) != Some(path) =>
          raise transfer_error(
            ProtocolFailure,
            "cannot resume into a different Content-Disposition output path",
          )
        _ => ()
      }
    }
    let skip_existing = if options.resume_skip_existing &&
      response.code == 200 &&
      response_has_body(response.code, request_method) {
      options.resume_from.unwrap_or(0L)
    } else {
      0L
    }
    if options.resume_skip_existing &&
      options.resume_from is Some(offset) &&
      offset > 0L {
      match output {
        FileOutput(mode=Truncate | Unique, ..) =>
          raise transfer_error(
            ProtocolFailure,
            "retaining a resumed prefix requires append output",
          )
        _ => ()
      }
    }
    if options.profile != WgetProfile &&
      skip_existing > 0L &&
      total is Some(expected) &&
      expected < skip_existing {
      raise transfer_error(
        ProtocolFailure,
        "response is shorter than the already written prefix",
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
        ) if offset > 0L && !options.resume_skip_existing =>
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition~,
            remove_on_error~,
          )
        _ => output
      }
    }
    let sink = TransferSink::new(effective_output, response, options.profile) catch {
      TransferError(..) as error =>
        raise with_failure_context(
          error,
          failure_context(
            ResponseBody,
            framing=response_framing(response, request_method),
          ),
        )
      error => raise error
    }
    let mut count = 0L
    let framing = response_framing(response, request_method)
    let received = sink.with_scope(() => {
      try {
        if !sink.deferred_open {
          sink.start(observer, response_offset)
        }
        let mut skip_remaining = skip_existing
        for ;; {
          let timeout = timeout_for(
            options,
            started,
            options.idle_timeout_ms,
            "response body",
          )
          let read_result = @async.with_timeout_opt(timeout, () => {
            client.read_some(max_len=65536, profile=options.profile)
          }) catch {
            @io.ReaderClosed =>
              raise response_body_eof(response, request_method, count)
            TransferError(..) as error => raise error
            err =>
              raise transfer_error(
                ReceiveFailure,
                "response body read failed: \{err}",
              )
          }
          let chunk = match read_result {
            Some(Some(chunk)) => chunk
            Some(None) => break
            None => raise timeout_message("response body", timeout)
          }
          let skipped = skip_remaining.min(chunk.length().to_int64()).to_int()
          skip_remaining -= skipped.to_int64()
          count += chunk.length().to_int64()
          if skipped < chunk.length() {
            sink.start(observer, response_offset)
            sink.write(
              if skipped == 0 {
                chunk
              } else {
                chunk[skipped:].to_owned()
              },
            )
          }
          emit(observer, Progress(received=count, content_length=total))
        }
        let expected_body_length = match response_span {
          Some(_) => response_span
          None => total
        }
        if response_has_body(response.code, request_method) &&
          expected_body_length is Some(expected) &&
          count != expected {
          raise transfer_error(
            PartialBodyFailure,
            "response body ended after \{count} of \{expected} bytes",
          )
        }
        let completed_shorter_wget_response = options.profile == WgetProfile &&
          response.code == 200 &&
          total == Some(count)
        if skip_remaining > 0L && !completed_shorter_wget_response {
          raise transfer_error(
            PartialBodyFailure,
            "response ended before the already written prefix",
          )
        }
        sink.start(observer, response_offset)
        sink.flush()
        count
      } catch {
        TransferError(..) as transfer_failure => {
          sink.flush_after_failure()
          sink.close()
          sink.cleanup_after_error() catch {
            _ => ()
          }
          client.close()
          raise response_body_failure(
            transfer_failure,
            framing,
            received_bytes=count,
            committed_bytes=sink.committed,
            write_outcome_uncertain=sink.write_uncertain,
          )
        }
        err => {
          sink.flush_after_failure()
          sink.close()
          sink.cleanup_after_error() catch {
            _ => ()
          }
          client.close()
          raise transfer_error(
            ReceiveFailure,
            "response transfer failed: \{err}",
            context=failure_context(
              ResponseBody,
              framing~,
              received_bytes=count,
              committed_bytes=sink.committed,
              write_outcome_uncertain=sink.write_uncertain,
            ),
          )
        }
      }
    })
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
