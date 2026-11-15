///|
priv struct Options {
  urls : Array[String]
  input_files : Array[String]
  mut help : Bool
  mut quiet : Bool
  mut output_document : String?
  mut log_file : String?
  mut append_log : Bool
  mut continue_download : Bool
  mut timestamping : Bool
  mut tries : Int32
  mut retry_connection_refused : Bool
  retry_http_statuses : Array[Int32]
  mut retry_delay_ms : Int32
  mut max_redirects : Int32
  mut content_disposition : Bool
  headers : Array[@netops.HttpHeader]
  mut request_method : @netops.HttpMethod
  mut method_explicit : Bool
  mut body : @netops.RequestBody
  mut body_options_conflict : Bool
  mut no_check_certificate : Bool
  mut no_proxy : Bool
  mut utf8_hosts : Bool
  mut connect_timeout_ms : Int32
  mut read_timeout_ms : Int32
  mut user : String?
  mut password : String?
  mut auth_no_challenge : Bool
  mut cookies : Bool
  mut load_cookies : String?
  mut save_cookies : String?
  mut keep_session_cookies : Bool
}

///|
priv suberror UsageError {
  UsageError(String)
}

///|
fn usage() -> String {
  let text = metadata_help().strip_suffix("\n").unwrap().to_owned()
  text + "\n"
}

///|
fn default_options() -> Options {
  {
    urls: [],
    input_files: [],
    help: false,
    quiet: DEFAULT_QUIET,
    output_document: None,
    log_file: None,
    append_log: false,
    continue_download: DEFAULT_CONTINUE_DOWNLOAD,
    timestamping: DEFAULT_TIMESTAMPING,
    tries: DEFAULT_TRIES,
    retry_connection_refused: DEFAULT_RETRY_CONNECTION_REFUSED,
    retry_http_statuses: [],
    retry_delay_ms: DEFAULT_RETRY_DELAY_MS,
    max_redirects: DEFAULT_MAX_REDIRECTS,
    content_disposition: DEFAULT_CONTENT_DISPOSITION,
    headers: [],
    request_method: @netops.Get,
    method_explicit: false,
    body: @netops.EmptyBody,
    body_options_conflict: false,
    no_check_certificate: DEFAULT_NO_CHECK_CERTIFICATE,
    no_proxy: DEFAULT_NO_PROXY,
    utf8_hosts: false,
    connect_timeout_ms: DEFAULT_CONNECT_TIMEOUT_MS,
    read_timeout_ms: DEFAULT_READ_TIMEOUT_MS,
    user: None,
    password: None,
    auth_no_challenge: DEFAULT_AUTH_NO_CHALLENGE,
    cookies: DEFAULT_COOKIES,
    load_cookies: None,
    save_cookies: None,
    keep_session_cookies: DEFAULT_KEEP_SESSION_COOKIES,
  }
}

///|
fn parse_nonnegative(value : String, option : String) -> Int32 raise UsageError {
  let result = @string.parse_int(value) catch {
    _ => raise UsageError("\{option}: invalid number '\{value}'")
  }
  if result < 0 {
    raise UsageError("\{option}: invalid number '\{value}'")
  }
  result
}

///|
fn parse_seconds(value : String, option : String) -> Int32 raise UsageError {
  @cli.parse_idle_timeout(value) catch {
    _ => raise UsageError("\{option}: invalid time period '\{value}'")
  }
}

///|
fn parse_header(value : String) -> @netops.HttpHeader raise UsageError {
  guard value.find(":") is Some(index) && index > 0 else {
    raise UsageError("--header: invalid header '\{value}'")
  }
  @netops.http_header(
    value[:index].to_owned().trim().to_owned(),
    value[index + 1:].to_owned().trim().to_owned(),
  )
}

///|
fn parse_statuses(value : String) -> Array[Int32] raise UsageError {
  let statuses : Array[Int32] = []
  for item in value.split(",") {
    let status = parse_nonnegative(
      item.trim().to_owned(),
      "--retry-on-http-error",
    )
    if status < 100 || status > 599 {
      raise UsageError("--retry-on-http-error: invalid HTTP status")
    }
    statuses.push(status)
  }
  statuses
}

///|
fn option_specs() -> Array[@cli.OptionSpec] {
  let specs = transfer_option_specs()
  specs.append(negative_option_specs())
  specs.append(enabled_option_specs())
  specs
}

///|
fn enabled(parsed : @cli.ParsedArgs, name : String) -> Bool {
  parsed.last_occurrence([name, "no-" + name]) == Some(name)
}

///|
fn parse_options(args : ArrayView[String]) -> Options raise UsageError {
  let specs = option_specs()
  let parsed = @cli.parse(auth_arguments(args, specs), specs) catch {
    @cli.CliError(option~, message~, ..) =>
      raise UsageError("\{message}: '\{option}'")
  }
  let options = default_options()
  options.urls.append(parsed.operands)
  options.input_files.append(parsed.values("input-file"))
  options.help = parsed.contains("help")
  options.quiet = enabled(parsed, "quiet")
  options.output_document = parsed.last_value("output-document")
  options.continue_download = enabled(parsed, "continue")
  options.timestamping = enabled(parsed, "timestamping")
  options.retry_connection_refused = enabled(parsed, "retry-connrefused")
  options.content_disposition = enabled(parsed, "content-disposition")
  options.no_check_certificate = parsed.last_occurrence([
      "check-certificate", "no-check-certificate",
    ]) ==
    Some("no-check-certificate")
  options.no_proxy = parsed.last_occurrence(["proxy", "no-proxy"]) ==
    Some("no-proxy")
  if parsed.last_value("local-encoding") is Some(value) {
    options.utf8_hosts = match value.to_lower().replace_all(old="-", new="") {
      "utf8" => true
      "ascii" | "usascii" | "ansi_x3.41968" => false
      _ =>
        raise UsageError(
          "--local-encoding: unsupported encoding '" + value + "'",
        )
    }
  }
  options.user = match parsed.last_value("http-user") {
    Some(value) => Some(value)
    None => parsed.last_value("user")
  }
  options.password = match parsed.last_value("http-password") {
    Some(value) => Some(value)
    None => parsed.last_value("password")
  }
  if parsed.last_value("auth-no-challenge") is Some(value) {
    options.auth_no_challenge = match value.to_lower() {
      "on" | "yes" | "1" => true
      "off" | "no" | "0" => false
      _ =>
        raise UsageError(
          "--auth-no-challenge: Invalid boolean '" +
          value +
          "'; use `on' or `off'.",
        )
    }
  }
  options.cookies = parsed.last_occurrence(["cookies", "no-cookies"]) !=
    Some("no-cookies")
  options.load_cookies = parsed.last_value("load-cookies")
  options.save_cookies = parsed.last_value("save-cookies")
  options.keep_session_cookies = enabled(parsed, "keep-session-cookies")
  match parsed.last_occurrence(["output-file", "append-output"]) {
    Some("output-file") => {
      options.log_file = parsed.last_value("output-file")
      options.append_log = false
    }
    Some("append-output") => {
      options.log_file = parsed.last_value("append-output")
      options.append_log = true
    }
    _ => ()
  }
  if parsed.last_value("tries") is Some(value) {
    options.tries = parse_nonnegative(value, "--tries")
  }
  if parsed.last_value("waitretry") is Some(value) {
    options.retry_delay_ms = parse_seconds(value, "--waitretry")
  }
  if parsed.last_value("max-redirect") is Some(value) {
    options.max_redirects = parse_nonnegative(value, "--max-redirect")
  }
  for value in parsed.values("retry-on-http-error") {
    options.retry_http_statuses.append(parse_statuses(value))
  }
  for value in parsed.values("header") {
    if value == "" {
      options.headers.clear()
    } else {
      options.headers.push(parse_header(value))
    }
  }
  if parsed.last_value("method") is Some(value) {
    options.request_method = @netops.parse_http_method(value) catch {
      _ => raise UsageError("--method: unsupported HTTP method '\{value}'")
    }
    options.method_explicit = true
  }
  options.body_options_conflict = parsed.contains("body-data") &&
    parsed.contains("body-file")
  match parsed.last_occurrence(["body-data", "body-file"]) {
    Some("body-data") => {
      let value = parsed.last_value("body-data").unwrap()
      options.body = @netops.BytesBody(@utf8.encode(value))
    }
    Some("body-file") => {
      let value = parsed.last_value("body-file").unwrap()
      options.body = if value == "-" {
        @netops.StdinBody
      } else {
        @netops.FileBody(value)
      }
    }
    _ => ()
  }
  if parsed.last_occurrence(["timeout", "connect-timeout"]) is Some(name) {
    options.connect_timeout_ms = parse_seconds(
      parsed.last_value(name).unwrap(),
      "--" + name,
    )
  }
  match parsed.last_occurrence(["timeout", "read-timeout", "idle-timeout"]) {
    Some(name) => {
      let value = parsed.last_value(name).unwrap()
      options.read_timeout_ms = parse_seconds(value, "--" + name)
    }
    None => ()
  }
  options
}
