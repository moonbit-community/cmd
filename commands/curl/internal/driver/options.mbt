///|
priv enum DataKind {
  FormData
  RawData
  BinaryData
  UrlEncodedData
}

///|
priv struct DataSpec {
  kind : DataKind
  value : String
}

///|
priv struct Options {
  urls : Array[String]
  output_specs : Array[String]
  mut remote_name : Bool
  mut remote_header_name : Bool
  mut silent : Bool
  mut show_error : Bool
  mut fail : Bool
  mut location : Bool
  mut max_redirects : Int32
  mut head : Bool
  mut request_method : @netops.HttpMethod?
  headers : Array[@netops.HttpHeader]
  suppressed_headers : Array[String]
  data_specs : Array[DataSpec]
  mut upload_file : String?
  mut retry_count : Int32
  mut retry_delay_ms : Int32
  mut retry_max_time_ms : Int32?
  mut retry_connection_refused : Bool
  mut retry_all_errors : Bool
  mut connect_timeout_ms : Int32
  mut max_time_ms : Int32?
  mut idle_timeout_ms : Int32
  mut insecure : Bool
  mut proxy_url : String?
  mut no_proxy : String?
  mut remove_on_error : Bool
  mut help : Bool
  mut user : String?
  cookies : Array[String]
  mut cookie_jar : String?
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
fn parse_nonnegative(value : String, option : String) -> Int32 raise UsageError {
  let result = @string.parse_int(value) catch {
    _ => raise UsageError("\{option}: expected a non-negative integer")
  }
  if result < 0 {
    raise UsageError("\{option}: expected a non-negative integer")
  }
  result
}

///|
fn parse_redirect_limit(value : String) -> Int32 raise UsageError {
  let result = @string.parse_int(value) catch {
    _ => raise UsageError("--max-redirs: expected -1 or a non-negative integer")
  }
  if result < -1 {
    raise UsageError("--max-redirs: expected -1 or a non-negative integer")
  }
  result
}

///|
fn parse_seconds(value : String, option : String) -> Int32 raise UsageError {
  @cli.parse_idle_timeout(value) catch {
    _ => raise UsageError("\{option}: expected a positive number of seconds")
  }
}

///|
fn parse_seconds_or_zero(
  value : String,
  option : String,
) -> Int32 raise UsageError {
  let seconds = @string.parse_double(value) catch {
    _ =>
      raise UsageError("\{option}: expected a non-negative number of seconds")
  }
  if seconds == 0.0 {
    return 0
  }
  if seconds < 0.0 {
    raise UsageError("\{option}: expected a non-negative number of seconds")
  }
  parse_seconds(value, option)
}

///|
fn parse_retry_seconds(
  value : String,
  option : String,
) -> Int32 raise UsageError {
  let seconds = @string.parse_int(value) catch {
    _ =>
      raise UsageError(
        "\{option}: expected a non-negative integer number of seconds",
      )
  }
  if seconds < 0 || seconds > 2_147_483 {
    raise UsageError("\{option}: seconds exceed the supported timer range")
  }
  seconds * 1000
}

///|
fn parse_header(
  value : String,
  raw~ : Bool = false,
) -> @netops.HttpHeader raise UsageError {
  if !value.contains(":") && value.has_suffix(";") && value.length() > 1 {
    return @netops.http_header(value[:value.length() - 1].to_owned(), "")
  }
  guard value.find(":") is Some(index) && index > 0 else {
    raise UsageError("--header: invalid header '\{value}'")
  }
  let name = value[:index].to_owned().trim().to_owned()
  let content = value[index + 1:].trim(chars=" \t").to_owned()
  if raw {
    @netops.http_header_bytes(name, @utf8.encode(content))
  } else {
    @netops.http_header(name, content)
  }
}

///|
fn default_options() -> Options {
  {
    urls: [],
    output_specs: [],
    remote_name: DEFAULT_REMOTE_NAME,
    remote_header_name: DEFAULT_REMOTE_HEADER_NAME,
    silent: DEFAULT_SILENT,
    show_error: DEFAULT_SHOW_ERROR,
    fail: DEFAULT_FAIL,
    location: DEFAULT_LOCATION,
    max_redirects: DEFAULT_MAX_REDIRECTS,
    head: DEFAULT_HEAD,
    request_method: None,
    headers: [],
    suppressed_headers: [],
    data_specs: [],
    upload_file: None,
    retry_count: DEFAULT_RETRY_COUNT,
    retry_delay_ms: DEFAULT_RETRY_DELAY_MS,
    retry_max_time_ms: None,
    retry_connection_refused: DEFAULT_RETRY_CONNECTION_REFUSED,
    retry_all_errors: DEFAULT_RETRY_ALL_ERRORS,
    connect_timeout_ms: DEFAULT_CONNECT_TIMEOUT_MS,
    max_time_ms: None,
    idle_timeout_ms: DEFAULT_IDLE_TIMEOUT_MS,
    insecure: DEFAULT_INSECURE,
    proxy_url: None,
    no_proxy: None,
    remove_on_error: DEFAULT_REMOVE_ON_ERROR,
    help: false,
    user: None,
    cookies: [],
    cookie_jar: None,
  }
}

///|
fn option_specs() -> Array[@cli.OptionSpec] {
  let specs = transfer_option_specs()
  specs.append(negative_option_specs())
  specs
}

///|
fn enabled(parsed : @cli.ParsedArgs, name : String) -> Bool {
  parsed.last_occurrence([name, "no-" + name]) == Some(name)
}

///|
fn parse_options(
  args : ArrayView[String],
  file_headers~ : Set[Int32] = Set([]),
) -> Options raise UsageError {
  let parsed = @cli.parse(args, option_specs()) catch {
    @cli.CliError(option~, message~, ..) =>
      raise UsageError("\{message}: '\{option}'")
  }
  let options = default_options()
  options.urls.append(parsed.operands)
  options.urls.append(parsed.values("url"))
  options.output_specs.append(parsed.values("output"))
  options.remote_name = enabled(parsed, "remote-name")
  options.remote_header_name = enabled(parsed, "remote-header-name")
  options.silent = enabled(parsed, "silent")
  options.show_error = enabled(parsed, "show-error")
  options.fail = enabled(parsed, "fail")
  options.location = enabled(parsed, "location")
  options.head = enabled(parsed, "head")
  options.retry_connection_refused = enabled(parsed, "retry-connrefused")
  options.retry_all_errors = enabled(parsed, "retry-all-errors")
  options.insecure = enabled(parsed, "insecure")
  options.remove_on_error = enabled(parsed, "remove-on-error")
  options.help = parsed.contains("help")
  options.user = parsed.last_value("user")
  if options.user is Some(user) && !user.contains(":") {
    raise UsageError(
      "--user requires user:password; interactive password entry is unavailable",
    )
  }
  options.cookies.append(parsed.values("cookie"))
  options.cookie_jar = parsed.last_value("cookie-jar")
  if parsed.last_value("max-redirs") is Some(value) {
    options.max_redirects = parse_redirect_limit(value)
  }
  for index, value in parsed.values("header") {
    let header = parse_header(value, raw=file_headers.contains(index))
    if value.contains(":") &&
      header.value == "" &&
      !["host", "transfer-encoding"].contains(header.name.to_lower()) {
      options.suppressed_headers.push(header.name.to_lower())
    } else {
      options.headers.push(header)
    }
  }
  if parsed.last_value("request") is Some(value) {
    options.request_method = Some(
      @netops.parse_http_method(value) catch {
        _ => raise UsageError("--request: unsupported HTTP method '\{value}'")
      },
    )
  }
  let data_positions : Map[String, Int32] = Map([])
  for name in parsed.order {
    if name == "data" ||
      name == "data-raw" ||
      name == "data-binary" ||
      name == "data-urlencode" {
      let position = data_positions.get(name).unwrap_or(0)
      let value = parsed.values(name)[position]
      data_positions[name] = position + 1
      options.data_specs.push({
        kind: match name {
          "data" => FormData
          "data-raw" => RawData
          "data-binary" => BinaryData
          _ => UrlEncodedData
        },
        value,
      })
    }
  }
  options.upload_file = parsed.last_value("upload-file")
  if parsed.last_value("retry") is Some(value) {
    options.retry_count = parse_nonnegative(value, "--retry")
  }
  if parsed.last_value("retry-delay") is Some(value) {
    options.retry_delay_ms = parse_retry_seconds(value, "--retry-delay")
  }
  if parsed.last_value("retry-max-time") is Some(value) {
    let timeout = parse_retry_seconds(value, "--retry-max-time")
    options.retry_max_time_ms = if timeout == 0 { None } else { Some(timeout) }
  }
  if parsed.last_value("connect-timeout") is Some(value) {
    let timeout = parse_seconds_or_zero(value, "--connect-timeout")
    options.connect_timeout_ms = if timeout == 0 {
      DEFAULT_CONNECT_TIMEOUT_MS
    } else {
      timeout
    }
  }
  if parsed.last_value("max-time") is Some(value) {
    let timeout = parse_seconds_or_zero(value, "--max-time")
    options.max_time_ms = if timeout == 0 { None } else { Some(timeout) }
  }
  if parsed.last_value("idle-timeout") is Some(value) {
    options.idle_timeout_ms = parse_seconds(value, "--idle-timeout")
  }
  options.proxy_url = parsed.last_value("proxy")
  options.no_proxy = parsed.last_value("noproxy")
  if options.data_specs.length() > 0 && options.upload_file is Some(_) {
    raise UsageError("--data and --upload-file are mutually exclusive")
  }
  if options.remote_header_name && !options.remote_name {
    raise UsageError("--remote-header-name requires --remote-name")
  }
  options
}
