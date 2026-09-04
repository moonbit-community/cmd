///|
fn curl_has_header(
  headers : ArrayView[@netops.HttpHeader],
  name : String,
) -> Bool {
  let normalized = name.to_lower()
  for header in headers {
    if header.name.to_lower() == normalized {
      return true
    }
  }
  false
}

///|
fn curl_without_line_endings(data : Bytes) -> Bytes {
  let output = @buffer.Buffer(size_hint=data.length())
  for byte in data {
    if byte != b'\r' && byte != b'\n' && byte != b'\x00' {
      output.write_byte(byte)
    }
  }
  output.to_bytes()
}

///|
fn curl_url_encoded(data : Bytes) -> Bytes {
  let output = @buffer.Buffer(size_hint=data.length())
  let digits = b"0123456789ABCDEF"
  for byte in data {
    let value = byte.to_int()
    if (value >= 0x41 && value <= 0x5A) ||
      (value >= 0x61 && value <= 0x7A) ||
      (value >= 0x30 && value <= 0x39) ||
      byte == b'-' ||
      byte == b'.' ||
      byte == b'_' ||
      byte == b'~' {
      output.write_byte(byte)
    } else {
      output.write_byte(b'%')
      output.write_byte(digits[value >> 4])
      output.write_byte(digits[value & 0x0F])
    }
  }
  output.to_bytes()
}

///|
async fn curl_data_value(spec : CurlDataSpec) -> Bytes {
  match spec.kind {
    RawData => @utf8.encode(spec.value)
    FormData =>
      if spec.value.has_prefix("@") {
        curl_without_line_endings(@fs.read_file(spec.value[1:]).binary())
      } else {
        @utf8.encode(spec.value)
      }
    BinaryData =>
      if spec.value.has_prefix("@") {
        @fs.read_file(spec.value[1:]).binary()
      } else {
        @utf8.encode(spec.value)
      }
    UrlEncodedData => {
      let value = spec.value
      if value.has_prefix("@") {
        curl_url_encoded(@fs.read_file(value[1:]).binary())
      } else if value.find("@") is Some(index) && index > 0 {
        let name = value[:index].to_owned()
        @utf8.encode(name + "=") +
        curl_url_encoded(@fs.read_file(value[index + 1:]).binary())
      } else if value.find("=") is Some(index) {
        @utf8.encode(value[:index + 1].to_owned()) +
        curl_url_encoded(@utf8.encode(value[index + 1:].to_owned()))
      } else {
        curl_url_encoded(@utf8.encode(value))
      }
    }
  }
}

///|
async fn curl_request_body(options : CurlOptions) -> @netops.RequestBody {
  if options.data_specs.length() > 0 {
    let output = @buffer.Buffer()
    for index, spec in options.data_specs {
      if index > 0 {
        output.write_byte(b'&')
      }
      output.write_bytes(curl_data_value(spec))
    }
    return @netops.BytesBody(output.to_bytes())
  }
  match options.upload_file {
    Some("-") => @netops.StdinBody
    Some(path) => @netops.FileBody(path)
    None => @netops.EmptyBody
  }
}

///|
fn curl_request_method(options : CurlOptions) -> @netops.HttpMethod {
  match options.request_method {
    Some(request) => request
    None if options.head => @netops.Head
    None if options.upload_file is Some(_) => @netops.Put
    None if options.data_specs.length() > 0 => @netops.Post
    None => @netops.Get
  }
}

///|
fn curl_proxy_for(options : CurlOptions, url : String) -> String? {
  let no_proxy = match options.no_proxy {
    Some(value) => Some(value)
    None =>
      match @env.get_env_var("NO_PROXY") {
        Some(value) => Some(value)
        None => @env.get_env_var("no_proxy")
      }
  }
  if @netops.proxy_bypassed(url, no_proxy) {
    return None
  }
  if options.proxy_url is Some(value) {
    return if value == "" { None } else { Some(value) }
  }
  let name = if url.to_lower().has_prefix("https://") {
    "https_proxy"
  } else {
    "http_proxy"
  }
  match @env.get_env_var(name) {
    Some(value) => Some(value)
    None if name == "https_proxy" =>
      match @env.get_env_var("HTTPS_PROXY") {
        Some(value) => Some(value)
        None =>
          match @env.get_env_var("ALL_PROXY") {
            Some(value) => Some(value)
            None => @env.get_env_var("all_proxy")
          }
      }
    None =>
      match @env.get_env_var("ALL_PROXY") {
        Some(value) => Some(value)
        None => @env.get_env_var("all_proxy")
      }
  }
}

///|
fn curl_output(
  options : CurlOptions,
  url : String,
  index : Int,
) -> @netops.TransferOutput raise @netops.TransferError {
  if index < options.output_specs.length() {
    let path = options.output_specs[index]
    return if path == "-" {
      @netops.StandardOutput
    } else {
      @netops.FileOutput(
        path~,
        mode=@netops.Truncate,
        content_disposition=false,
        remove_on_error=options.remove_on_error,
      )
    }
  }
  if options.remote_name {
    let normalized = match url.find("#") {
      Some(index) => url[:index].to_owned()
      None => url
    }
    let normalized = match normalized.find("?") {
      Some(index) => normalized[:index].to_owned()
      None => normalized
    }
    if normalized.has_suffix("/") {
      raise @netops.TransferError(
        kind=@netops.OutputFailure,
        message="Remote filename has no length",
        status=None,
      )
    }
    let path = @netops.remote_name(url)
    return @netops.FileOutput(
      path~,
      mode=@netops.Truncate,
      content_disposition=options.remote_header_name,
      remove_on_error=options.remove_on_error,
    )
  }
  @netops.StandardOutput
}

///|
fn curl_exit_kind(kind : @netops.TransferErrorKind) -> Int {
  match kind {
    @netops.UnsupportedProtocol => 1
    @netops.InvalidMethod | @netops.ProtocolFailure => 2
    @netops.InvalidUrl => 3
    @netops.ProxyFailure => 5
    @netops.ConnectionFailure => 7
    @netops.HttpStatusFailure => 22
    @netops.OutputFailure => 23
    @netops.InputFailure => 26
    @netops.TimeoutFailure => 28
    @netops.RedirectFailure => 47
    @netops.TlsFailure => 60
  }
}

///|
async fn curl_write_headers(
  status : Int,
  reason : String,
  headers : ArrayView[@netops.HttpHeader],
) -> Unit {
  @stdio.stdout.write("HTTP/1.1 \{status} \{reason}\r\n")
  for header in headers {
    @stdio.stdout.write("\{header.name}: \{header.value}\r\n")
  }
  @stdio.stdout.write("\r\n")
}

///|
fn curl_progress_text(
  received : Int64,
  content_length : Int64?,
  interactive : Bool,
  completed : Bool,
) -> String {
  let percent = match content_length {
    Some(total) if total > 0L =>
      (received.to_double() * 100.0 / total.to_double())
      .clamp(min=0.0, max=100.0)
      .to_int()
    _ => 0
  }
  if interactive {
    "\r\{percent}% \{received}" + (if completed { "\n" } else { "\u{1b}[K" })
  } else if completed {
    "\{percent}% \{received}\n"
  } else {
    ""
  }
}

///|
async fn curl_observer(
  show_headers : Bool,
  show_progress : Bool,
  interactive : Bool,
  event : @netops.TransferEvent,
) -> Unit {
  match event {
    @netops.ResponseStarted(status~, reason~, headers~, ..) => {
      if show_headers {
        curl_write_headers(status, reason, headers)
      }
      if show_progress {
        @stdio.stderr.write(
          "  % Total    % Received  Average Speed   Time    Time     Time  Current\n",
        )
      }
    }
    @netops.Progress(received~, content_length~) if show_progress => {
      let text = curl_progress_text(
        received, content_length, interactive, false,
      )
      if text != "" {
        @stdio.stderr.write(text)
      }
    }
    @netops.Completed(received~, content_length~) if show_progress =>
      @stdio.stderr.write(
        curl_progress_text(received, content_length, interactive, true),
      )
    _ => ()
  }
}

///|
fn curl_can_retry(
  options : CurlOptions,
  kind : @netops.TransferErrorKind,
  status : Int?,
) -> Bool {
  if options.retry_all_errors {
    return kind != @netops.InputFailure && kind != @netops.OutputFailure
  }
  match kind {
    @netops.HttpStatusFailure => @netops.retryable_failure(kind, status)
    @netops.ConnectionFailure => options.retry_connection_refused
    @netops.TimeoutFailure => true
    _ => false
  }
}

///|
fn curl_retry_delay(options : CurlOptions, attempt : Int) -> Int {
  if options.retry_delay_ms > 0 {
    return options.retry_delay_ms
  }
  let exponent = (attempt - 1).clamp(min=0, max=10)
  (1000 << exponent).min(600_000)
}

///|
async fn curl_transfer_one(
  options : CurlOptions,
  url : String,
  index : Int,
) -> Int {
  let body = curl_request_body(options) catch {
    err => {
      if !options.silent || options.show_error {
        @stdio.stderr.write("curl: (26) \{err}\n")
      }
      return 26
    }
  }
  let headers = options.headers.copy()
  if !curl_has_header(headers, "user-agent") {
    headers.push(@netops.http_header("User-Agent", "curl/8.22.0"))
  }
  if !curl_has_header(headers, "accept") {
    headers.push(@netops.http_header("Accept", "*/*"))
  }
  if options.data_specs.length() > 0 &&
    !curl_has_header(headers, "content-type") {
    headers.push(
      @netops.http_header("Content-Type", "application/x-www-form-urlencoded"),
    )
  }
  let output = try {
    if options.head {
      @netops.DiscardOutput
    } else {
      curl_output(options, url, index)
    }
  } catch {
    @netops.TransferError(kind~, message~, ..) => {
      let code = curl_exit_kind(kind)
      if !options.silent || options.show_error {
        @stdio.stderr.write("curl: (\{code}) \{message}\n")
      }
      return code
    }
  }
  let stdout_terminal = @platform.terminal_output_enabled(
    @platform.IfTerminal,
    @platform.Stdout,
  )
  let stderr_terminal = @platform.terminal_output_enabled(
    @platform.IfTerminal,
    @platform.Stderr,
  )
  let writes_stdout = match output {
    @netops.StandardOutput => true
    _ => false
  }
  let show_progress = !options.silent && !(writes_stdout && stdout_terminal)
  let mut attempt = 0
  let retry_started = @async.now()
  for ;; {
    let transient_statuses = if attempt < options.retry_count {
      [408, 429, 500, 502, 503, 504]
    } else {
      []
    }
    let proxy_url = curl_proxy_for(options, url)
    let result = try
      @netops.transfer(
        url,
        output,
        @netops.transfer_options(
          request_method=curl_request_method(options),
          headers~,
          body~,
          redirects=if options.location {
            @netops.FollowRedirects(
              if options.max_redirects == -1 {
                2147483647
              } else {
                options.max_redirects
              },
            )
          } else {
            @netops.NoRedirects
          },
          preserve_method_on_redirect=options.request_method is Some(_),
          verify_tls=!options.insecure,
          proxy_url?,
          connect_timeout_ms=options.connect_timeout_ms,
          idle_timeout_ms=options.idle_timeout_ms,
          max_time_ms?=options.max_time_ms,
          fail_on_http_error=options.fail,
          http_error_statuses=transient_statuses,
        ),
        observer=event => {
          curl_observer(options.head, show_progress, stderr_terminal, event)
        },
      )
    catch {
      @netops.TransferError(kind~, message~, status~) => {
        if attempt < options.retry_count &&
          curl_can_retry(options, kind, status) {
          let next_attempt = attempt + 1
          let retry_delay = curl_retry_delay(options, next_attempt)
          let elapsed = @async.now() - retry_started
          if options.retry_max_time_ms is None ||
            elapsed + retry_delay.to_int64() <
            options.retry_max_time_ms.unwrap().to_int64() {
            attempt = next_attempt
            if !options.silent {
              @stdio.stderr.write(
                "Warning: transient problem: \{message}. Retrying...\n",
              )
            }
            @async.sleep(retry_delay)
            continue
          }
        }
        let code = curl_exit_kind(kind)
        if !options.silent || options.show_error {
          @stdio.stderr.write("curl: (\{code}) \{message}\n")
        }
        return code
      }
      err => {
        if !options.silent || options.show_error {
          @stdio.stderr.write("curl: (1) \{err}\n")
        }
        return 1
      }
    } noraise {
      value => value
    }
    ignore(result)
    return 0
  }
}

///|
async fn curl_run(options : CurlOptions) -> Int {
  if options.help {
    @stdio.stdout.write(curl_usage())
    return 0
  }
  if options.urls.is_empty() {
    @stdio.stderr.write("curl: try 'curl --help' for more information\n")
    return 2
  }
  let mut status = 0
  for index, url in options.urls {
    status = curl_transfer_one(options, url, index)
  }
  status
}

///|
async fn main {
  let options = parse_curl_options(@env.args()[1:]) catch {
    CurlUsageError(message) => {
      @stdio.stderr.write("curl: option error: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let status = curl_run(options)
  if status != 0 {
    @sys.exit(status)
  }
}
