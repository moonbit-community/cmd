///|
priv enum CurlDataKind {
  FormData
  RawData
  BinaryData
  UrlEncodedData
}

///|
priv struct CurlDataSpec {
  kind : CurlDataKind
  value : String
}

///|
struct CurlOptions {
  urls : Array[String]
  output_specs : Array[String]
  mut remote_name : Bool
  mut remote_header_name : Bool
  mut silent : Bool
  mut show_error : Bool
  mut fail : Bool
  mut location : Bool
  mut max_redirects : Int
  mut head : Bool
  mut request_method : @netops.HttpMethod?
  headers : Array[@netops.HttpHeader]
  data_specs : Array[CurlDataSpec]
  mut upload_file : String?
  mut retry_count : Int
  mut retry_delay_ms : Int
  mut retry_max_time_ms : Int?
  mut retry_connection_refused : Bool
  mut retry_all_errors : Bool
  mut connect_timeout_ms : Int
  mut max_time_ms : Int?
  mut idle_timeout_ms : Int
  mut insecure : Bool
  mut proxy_url : String?
  mut no_proxy : String?
  mut remove_on_error : Bool
  mut help : Bool
}

///|
suberror CurlUsageError {
  CurlUsageError(String)
}

///|
fn curl_usage() -> String {
  let text =
    #|Usage: curl [options...] <url>
    #|  -s, --silent                 silent mode
    #|  -S, --show-error             show errors with --silent
    #|  -f, --fail                   fail on HTTP response codes >= 400
    #|  -o, --output <file>          write to file instead of stdout
    #|  -O, --remote-name            use the remote file name
    #|  -J, --remote-header-name     use Content-Disposition with -O
    #|  -L, --location               follow redirects
    #|      --max-redirs <num>       maximum redirects (default 50)
    #|  -I, --head                   show response headers only
    #|  -H, --header <header>        pass a custom header to the server
    #|  -X, --request <method>       specify a supported HTTP method
    #|  -d, --data <data>            HTTP POST data
    #|      --data-raw <data>        HTTP POST data without @ expansion
    #|      --data-binary <data>     HTTP POST data without conversion
    #|      --data-urlencode <data>  URL-encode HTTP POST data
    #|  -T, --upload-file <file>     stream file as an upload
    #|      --retry <num>            retry transient failures
    #|      --retry-delay <seconds>  wait between retries
    #|      --retry-max-time <secs>  maximum time spent retrying
    #|      --retry-connrefused      retry connection refused failures
    #|      --retry-all-errors       retry all transfer errors
    #|      --connect-timeout <secs> maximum connection setup time
    #|  -m, --max-time <seconds>     maximum time for one transfer
    #|      --idle-timeout <seconds> extension: inactivity timeout
    #|  -k, --insecure               allow insecure TLS connections
    #|  -x, --proxy <url>            use this proxy
    #|      --noproxy <list>         bypass proxy for matching hosts
    #|      --remove-on-error        remove output file after transfer failure
    #|
    #|Compatibility limits: HTTP/HTTPS only; -X accepts GET, HEAD, POST, PUT,
    #|DELETE, CONNECT, OPTIONS, TRACE, and PATCH. Timer values are bounded by
    #|the runtime millisecond timer range.
  text
}

///|
fn curl_nonnegative(
  value : String,
  option : String,
) -> Int raise CurlUsageError {
  let result = @string.parse_int(value) catch {
    _ => raise CurlUsageError("\{option}: expected a non-negative integer")
  }
  if result < 0 {
    raise CurlUsageError("\{option}: expected a non-negative integer")
  }
  result
}

///|
fn curl_redirect_limit(value : String) -> Int raise CurlUsageError {
  let result = @string.parse_int(value) catch {
    _ =>
      raise CurlUsageError(
        "--max-redirs: expected -1 or a non-negative integer",
      )
  }
  if result < -1 {
    raise CurlUsageError("--max-redirs: expected -1 or a non-negative integer")
  }
  result
}

///|
fn curl_seconds(value : String, option : String) -> Int raise CurlUsageError {
  @cli.parse_idle_timeout(value) catch {
    _ =>
      raise CurlUsageError("\{option}: expected a positive number of seconds")
  }
}

///|
fn curl_seconds_or_zero(
  value : String,
  option : String,
) -> Int raise CurlUsageError {
  let seconds = @string.parse_double(value) catch {
    _ =>
      raise CurlUsageError(
        "\{option}: expected a non-negative number of seconds",
      )
  }
  if seconds == 0.0 {
    return 0
  }
  if seconds < 0.0 {
    raise CurlUsageError("\{option}: expected a non-negative number of seconds")
  }
  curl_seconds(value, option)
}

///|
fn curl_retry_seconds(
  value : String,
  option : String,
) -> Int raise CurlUsageError {
  let seconds = @string.parse_int(value) catch {
    _ =>
      raise CurlUsageError(
        "\{option}: expected a non-negative integer number of seconds",
      )
  }
  if seconds < 0 || seconds > 2_147_483 {
    raise CurlUsageError("\{option}: seconds exceed the supported timer range")
  }
  seconds * 1000
}

///|
fn curl_header(value : String) -> @netops.HttpHeader raise CurlUsageError {
  guard value.find(":") is Some(index) && index > 0 else {
    raise CurlUsageError("--header: invalid header '\{value}'")
  }
  @netops.http_header(
    value[:index].to_owned().trim().to_owned(),
    value[index + 1:].to_owned().trim().to_owned(),
  )
}

///|
fn default_curl_options() -> CurlOptions {
  {
    urls: [],
    output_specs: [],
    remote_name: false,
    remote_header_name: false,
    silent: false,
    show_error: false,
    fail: false,
    location: false,
    max_redirects: 50,
    head: false,
    request_method: None,
    headers: [],
    data_specs: [],
    upload_file: None,
    retry_count: 0,
    retry_delay_ms: 0,
    retry_max_time_ms: None,
    retry_connection_refused: false,
    retry_all_errors: false,
    connect_timeout_ms: 300_000,
    max_time_ms: None,
    idle_timeout_ms: 300_000,
    insecure: false,
    proxy_url: None,
    no_proxy: None,
    remove_on_error: false,
    help: false,
  }
}

///|
fn parse_curl_options(
  args : ArrayView[String],
) -> CurlOptions raise CurlUsageError {
  let parsed = @cli.parse(args, [
    @cli.flag("silent", short='s'),
    @cli.flag("show-error", short='S'),
    @cli.flag("fail", short='f'),
    @cli.option("output", short='o'),
    @cli.flag("remote-name", short='O'),
    @cli.flag("remote-header-name", short='J'),
    @cli.flag("location", short='L'),
    @cli.option("max-redirs"),
    @cli.flag("head", short='I'),
    @cli.option("header", short='H'),
    @cli.option("request", short='X'),
    @cli.option("data", short='d'),
    @cli.option("data-raw"),
    @cli.option("data-binary"),
    @cli.option("data-urlencode"),
    @cli.option("upload-file", short='T'),
    @cli.option("retry"),
    @cli.option("retry-delay"),
    @cli.option("retry-max-time"),
    @cli.flag("retry-connrefused"),
    @cli.flag("retry-all-errors"),
    @cli.option("connect-timeout"),
    @cli.option("max-time", short='m'),
    @cli.option("idle-timeout"),
    @cli.flag("insecure", short='k'),
    @cli.option("proxy", short='x'),
    @cli.option("noproxy"),
    @cli.flag("remove-on-error"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) =>
      raise CurlUsageError("\{message}: '\{option}'")
  }
  let options = default_curl_options()
  options.urls.append(parsed.operands)
  options.output_specs.append(parsed.values("output"))
  options.remote_name = parsed.contains("remote-name")
  options.remote_header_name = parsed.contains("remote-header-name")
  options.silent = parsed.contains("silent")
  options.show_error = parsed.contains("show-error")
  options.fail = parsed.contains("fail")
  options.location = parsed.contains("location")
  options.head = parsed.contains("head")
  options.retry_connection_refused = parsed.contains("retry-connrefused")
  options.retry_all_errors = parsed.contains("retry-all-errors")
  options.insecure = parsed.contains("insecure")
  options.remove_on_error = parsed.contains("remove-on-error")
  options.help = parsed.contains("help")
  if parsed.last_value("max-redirs") is Some(value) {
    options.max_redirects = curl_redirect_limit(value)
  }
  for value in parsed.values("header") {
    options.headers.push(curl_header(value))
  }
  if parsed.last_value("request") is Some(value) {
    options.request_method = Some(
      @netops.parse_http_method(value) catch {
        _ =>
          raise CurlUsageError("--request: unsupported HTTP method '\{value}'")
      },
    )
  }
  let data_positions : Map[String, Int] = Map([])
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
    options.retry_count = curl_nonnegative(value, "--retry")
  }
  if parsed.last_value("retry-delay") is Some(value) {
    options.retry_delay_ms = curl_retry_seconds(value, "--retry-delay")
  }
  if parsed.last_value("retry-max-time") is Some(value) {
    let timeout = curl_retry_seconds(value, "--retry-max-time")
    options.retry_max_time_ms = if timeout == 0 { None } else { Some(timeout) }
  }
  if parsed.last_value("connect-timeout") is Some(value) {
    let timeout = curl_seconds_or_zero(value, "--connect-timeout")
    options.connect_timeout_ms = if timeout == 0 { 300_000 } else { timeout }
  }
  if parsed.last_value("max-time") is Some(value) {
    let timeout = curl_seconds_or_zero(value, "--max-time")
    options.max_time_ms = if timeout == 0 { None } else { Some(timeout) }
  }
  if parsed.last_value("idle-timeout") is Some(value) {
    options.idle_timeout_ms = curl_seconds(value, "--idle-timeout")
  }
  options.proxy_url = parsed.last_value("proxy")
  options.no_proxy = parsed.last_value("noproxy")
  if options.data_specs.length() > 0 && options.upload_file is Some(_) {
    raise CurlUsageError("--data and --upload-file are mutually exclusive")
  }
  if options.remote_header_name && !options.remote_name {
    raise CurlUsageError("--remote-header-name requires --remote-name")
  }
  options
}
