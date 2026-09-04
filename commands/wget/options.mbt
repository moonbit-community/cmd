///|
struct WgetOptions {
  urls : Array[String]
  input_files : Array[String]
  mut help : Bool
  mut quiet : Bool
  mut output_document : String?
  mut log_file : String?
  mut append_log : Bool
  mut continue_download : Bool
  mut timestamping : Bool
  mut tries : Int
  mut retry_connection_refused : Bool
  retry_http_statuses : Array[Int]
  mut retry_delay_ms : Int
  mut max_redirects : Int
  mut content_disposition : Bool
  headers : Array[@netops.HttpHeader]
  mut request_method : @netops.HttpMethod
  mut method_explicit : Bool
  mut body : @netops.RequestBody
  mut body_options_conflict : Bool
  mut no_check_certificate : Bool
  mut no_proxy : Bool
  mut connect_timeout_ms : Int
  mut read_timeout_ms : Int
}

///|
suberror WgetUsageError {
  WgetUsageError(String)
}

///|
fn usage() -> String {
  let text =
    #|Usage: wget [OPTION]... [URL]...
    #|  -q, --quiet                     quiet (no output)
    #|  -O, --output-document=FILE      write documents to FILE
    #|  -o, --output-file=FILE          log messages to FILE
    #|  -a, --append-output=FILE        append messages to FILE
    #|  -i, --input-file=FILE           download URLs found in FILE
    #|  -c, --continue                  resume a partially downloaded file
    #|  -N, --timestamping              do not re-retrieve unchanged files
    #|  -t, --tries=NUMBER              set number of retries (0 means unlimited)
    #|      --retry-connrefused         retry even if the connection is refused
    #|      --retry-on-http-error=CODES retry comma-separated HTTP status codes
    #|      --waitretry=SECONDS         wait between retries
    #|      --max-redirect=NUMBER       maximum redirects (default 20)
    #|      --content-disposition       honor Content-Disposition filenames
    #|      --header=STRING             insert STRING among request headers
    #|      --method=HTTPMethod         use a supported HTTP method
    #|      --body-data=STRING          send STRING with an explicit --method
    #|      --body-file=FILE            send FILE with an explicit --method
    #|      --no-check-certificate      disable TLS certificate verification
    #|      --no-proxy                  do not use proxy environment variables
    #|  -T, --timeout=SECONDS           set connect and read timeouts
    #|      --connect-timeout=SECONDS   set connection timeout
    #|      --read-timeout=SECONDS      set response inactivity timeout
    #|      --idle-timeout=SECONDS      extension: response inactivity timeout
    #|
    #|Compatibility limits: HTTP/HTTPS only; --method accepts GET, HEAD, POST,
    #|PUT, DELETE, CONNECT, OPTIONS, TRACE, and PATCH. Timer values are bounded
    #|by the runtime millisecond timer range.
  text
}

///|
fn default_options() -> WgetOptions {
  {
    urls: [],
    input_files: [],
    help: false,
    quiet: false,
    output_document: None,
    log_file: None,
    append_log: false,
    continue_download: false,
    timestamping: false,
    tries: 20,
    retry_connection_refused: false,
    retry_http_statuses: [],
    retry_delay_ms: 0,
    max_redirects: 20,
    content_disposition: false,
    headers: [],
    request_method: @netops.Get,
    method_explicit: false,
    body: @netops.EmptyBody,
    body_options_conflict: false,
    no_check_certificate: false,
    no_proxy: false,
    connect_timeout_ms: 900_000,
    read_timeout_ms: 900_000,
  }
}

///|
fn parse_nonnegative(
  value : String,
  option : String,
) -> Int raise WgetUsageError {
  let result = @string.parse_int(value) catch {
    _ => raise WgetUsageError("\{option}: invalid number '\{value}'")
  }
  if result < 0 {
    raise WgetUsageError("\{option}: invalid number '\{value}'")
  }
  result
}

///|
fn parse_seconds(value : String, option : String) -> Int raise WgetUsageError {
  @cli.parse_idle_timeout(value) catch {
    _ => raise WgetUsageError("\{option}: invalid time period '\{value}'")
  }
}

///|
fn parse_header(value : String) -> @netops.HttpHeader raise WgetUsageError {
  guard value.find(":") is Some(index) && index > 0 else {
    raise WgetUsageError("--header: invalid header '\{value}'")
  }
  @netops.http_header(
    value[:index].to_owned().trim().to_owned(),
    value[index + 1:].to_owned().trim().to_owned(),
  )
}

///|
fn parse_statuses(value : String) -> Array[Int] raise WgetUsageError {
  let statuses : Array[Int] = []
  for item in value.split(",") {
    let status = parse_nonnegative(
      item.trim().to_owned(),
      "--retry-on-http-error",
    )
    if status < 100 || status > 599 {
      raise WgetUsageError("--retry-on-http-error: invalid HTTP status")
    }
    statuses.push(status)
  }
  statuses
}

///|
fn parse_wget_options(
  args : ArrayView[String],
) -> WgetOptions raise WgetUsageError {
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='q'),
    @cli.option("output-document", short='O'),
    @cli.option("output-file", short='o'),
    @cli.option("append-output", short='a'),
    @cli.option("input-file", short='i'),
    @cli.flag("continue", short='c'),
    @cli.flag("timestamping", short='N'),
    @cli.option("tries", short='t'),
    @cli.flag("retry-connrefused"),
    @cli.option("retry-on-http-error"),
    @cli.option("waitretry"),
    @cli.option("max-redirect"),
    @cli.flag("content-disposition"),
    @cli.option("header"),
    @cli.option("method"),
    @cli.option("body-data"),
    @cli.option("body-file"),
    @cli.flag("no-check-certificate"),
    @cli.flag("no-proxy"),
    @cli.option("timeout", short='T'),
    @cli.option("connect-timeout"),
    @cli.option("read-timeout"),
    @cli.option("idle-timeout"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) =>
      raise WgetUsageError("\{message}: '\{option}'")
  }
  let options = default_options()
  options.urls.append(parsed.operands)
  options.input_files.append(parsed.values("input-file"))
  options.help = parsed.contains("help")
  options.quiet = parsed.contains("quiet")
  options.output_document = parsed.last_value("output-document")
  options.continue_download = parsed.contains("continue")
  options.timestamping = parsed.contains("timestamping")
  options.retry_connection_refused = parsed.contains("retry-connrefused")
  options.content_disposition = parsed.contains("content-disposition")
  options.no_check_certificate = parsed.contains("no-check-certificate")
  options.no_proxy = parsed.contains("no-proxy")
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
    options.headers.push(parse_header(value))
  }
  if parsed.last_value("method") is Some(value) {
    options.request_method = @netops.parse_http_method(value) catch {
      _ => raise WgetUsageError("--method: unsupported HTTP method '\{value}'")
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
  if parsed.last_value("timeout") is Some(value) {
    let timeout = parse_seconds(value, "--timeout")
    options.connect_timeout_ms = timeout
    options.read_timeout_ms = timeout
  }
  if parsed.last_value("connect-timeout") is Some(value) {
    options.connect_timeout_ms = parse_seconds(value, "--connect-timeout")
  }
  match parsed.last_occurrence(["read-timeout", "idle-timeout"]) {
    Some(name) => {
      let value = parsed.last_value(name).unwrap()
      options.read_timeout_ms = parse_seconds(value, "--read-timeout")
    }
    None => ()
  }
  options
}
