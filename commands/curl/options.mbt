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
struct Options {
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
suberror UsageError {
  UsageError(String)
}

///|
fn usage() -> String {
  let text =
    #|Usage: curl [options...] <url>
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|  -s, --silent                 silent mode
    #|  -S, --show-error             show errors with --silent
    #|  -f, --fail                   fail on HTTP response codes >= 400
    #|  -o, --output <file>          write to file instead of stdout
    #|  -O, --remote-name            use the remote file name
    #|  -J, --remote-header-name     use Content-Disposition with -O
    #|  -L, --location               follow redirects
    #|      --max-redirs <num>       maximum redirects (default 50)
    #|  -I, --head                   show response headers only
    #|  -H, --header <header>        send custom fields in order, retaining repeats
    #|  -u, --user <user:password>   HTTP Basic authentication
    #|  -b, --cookie <data|file>     send cookies or load a Netscape jar
    #|  -c, --cookie-jar <file>      write a Netscape cookie jar
    #|      -H 'Cookie: ...'       send a separate field after stored jar cookies
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
    #|      --remove-on-error        remove opened output after final failure
    #|Already written stdout remains; final partial files remain without cleanup.
    #|Cookie values containing CR/LF are rejected before request bytes are sent.
    #|Final response fields retain order and repetition; request Content-Length is singular.
    #|Raw space/TAB/CR/LF/DEL in an initial URL path or query exits 3 before connecting.
    #|Redirect spaces use %20 in paths and + in queries; TAB uses %09.
    #|Set-Cookie without '=' is ignored; nonnumeric Max-Age deletes its stored cookie.
    #|Positive decimal Max-Age overflow keeps the new cookie under a 400-day cap.
    #|Stored __Secure-/__Host- cookies require Secure and the effective prefix scope.
    #|Secure cookie contexts are HTTPS or exact localhost/127.0.0.1/::1.
    #|Insecure origins cannot overlay live Secure cookies.
    #|Cookie domains preserve ASCII case and use the pinned ICANN/PRIVATE suffix list.
    #|UTF-8 locales enable pinned Unicode 15 URL-host IDNA with whole-host fallback.
    #|Other input encodings and Cookie Domain normalization remain unsupported.
    #|An empty HTTP reply exits 52; incomplete bodies exit 18; receive errors exit 56.
    #|An initial empty failure leaves ordinary unopened output untouched.
    #|An accepted retry resets an opened regular file before the next request.
    #|-O -J creates valid Content-Disposition filenames exclusively for 2xx/3xx.
    #|An existing selected filename exits 23 untouched; retries retain the first name.
    #|File write errors exit 23; an earlier transfer failure keeps its exit status.
    #|A redirect requiring already uploaded stdin to rewind exits 65.
    #|-sS keeps each failed attempt's error visible even if a later retry succeeds.
    #|Content-coding bytes remain encoded; Accept-Encoding defaults to identity.
    #|
    #|Compatibility limits: HTTP/HTTPS only; -X accepts GET, HEAD, POST, PUT,
    #|DELETE, CONNECT, OPTIONS, TRACE, and PATCH. Timer values are bounded by
    #|the runtime millisecond timer range.
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
fn default_options() -> Options {
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
    user: None,
    cookies: [],
    cookie_jar: None,
  }
}

///|
fn parse_options(args : ArrayView[String]) -> Options raise UsageError {
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
    @cli.option("user", short='u'),
    @cli.flag("basic"),
    @cli.option("cookie", short='b'),
    @cli.option("cookie-jar", short='c'),
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
      raise UsageError("\{message}: '\{option}'")
  }
  let options = default_options()
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
  for value in parsed.values("header") {
    options.headers.push(parse_header(value))
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
    options.connect_timeout_ms = if timeout == 0 { 300_000 } else { timeout }
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
