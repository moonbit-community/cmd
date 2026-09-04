///|
priv enum LogDestination {
  LogDisabled
  LogStderr
  LogFile(@fs.File)
}

///|
async fn LogDestination::write(self : LogDestination, text : String) -> Unit {
  match self {
    LogDisabled => ()
    LogStderr => @stdio.stderr.write(text)
    LogFile(file) => file.write(text)
  }
}

///|
fn LogDestination::close(self : LogDestination) -> Unit {
  match self {
    LogFile(file) => file.close()
    LogDisabled | LogStderr => ()
  }
}

///|
async fn open_log(options : WgetOptions) -> LogDestination {
  if options.quiet {
    return LogDisabled
  }
  match options.log_file {
    None => LogStderr
    Some(path) =>
      LogFile(
        @fs.open(
          path,
          mode=WriteOnly,
          append=options.append_log,
          create_mode=if options.append_log {
            OpenOrCreate
          } else {
            CreateOrTruncate
          },
        ),
      )
  }
}

///|
async fn read_url_file(path : String) -> Array[String] {
  let text = if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
  let urls : Array[String] = []
  for line in text.split("\n") {
    let value = line.trim().to_owned()
    if value != "" && !value.has_prefix("#") {
      urls.push(value)
    }
  }
  urls
}

///|
fn two_digits(value : Int) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    value.to_string()
  }
}

///|
fn http_weekday(value : @time.Weekday) -> String {
  match value {
    Monday => "Mon"
    Tuesday => "Tue"
    Wednesday => "Wed"
    Thursday => "Thu"
    Friday => "Fri"
    Saturday => "Sat"
    Sunday => "Sun"
  }
}

///|
fn http_month(value : Int) -> String {
  match value {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    12 => "Dec"
    _ => "Jan"
  }
}

///|
fn http_date(seconds : Int64) -> String raise {
  let value = @time.unix(seconds)
  "\{http_weekday(value.weekday())}, \{two_digits(value.day())} " +
  "\{http_month(value.month())} \{value.year()} " +
  "\{two_digits(value.hour())}:\{two_digits(value.minute())}:" +
  "\{two_digits(value.second())} GMT"
}

///|
async fn timestamp_header(path : String) -> @netops.HttpHeader? {
  if !@fs.exists(path) {
    return None
  }
  let (seconds, _) = @fs.mtime(path)
  Some(@netops.http_header("If-Modified-Since", http_date(seconds)))
}

///|
fn proxy_for(url : String, disabled : Bool) -> String? {
  if disabled {
    return None
  }
  let no_proxy = match @env.get_env_var("NO_PROXY") {
    Some(value) => Some(value)
    None => @env.get_env_var("no_proxy")
  }
  if @netops.proxy_bypassed(url, no_proxy) {
    return None
  }
  let scheme_name = if url.to_lower().has_prefix("https://") {
    "https_proxy"
  } else {
    "http_proxy"
  }
  match @env.get_env_var(scheme_name) {
    Some(value) => Some(value)
    None =>
      match @env.get_env_var(scheme_name.to_upper()) {
        Some(value) => Some(value)
        None => @env.get_env_var("all_proxy")
      }
  }
}

///|
fn wget_exit_kind(kind : @netops.TransferErrorKind) -> Int {
  match kind {
    @netops.HttpStatusFailure => 8
    @netops.TlsFailure => 5
    @netops.InputFailure | @netops.OutputFailure => 3
    @netops.UnsupportedProtocol
    | @netops.InvalidMethod
    | @netops.ProtocolFailure
    | @netops.RedirectFailure => 7
    @netops.InvalidUrl
    | @netops.ConnectionFailure
    | @netops.ProxyFailure
    | @netops.TimeoutFailure => 4
  }
}

///|
fn wget_can_retry(
  options : WgetOptions,
  kind : @netops.TransferErrorKind,
  status : Int?,
  message : String,
) -> Bool {
  let retry_http = match status {
    Some(value) => options.retry_http_statuses.contains(value)
    None => false
  }
  if retry_http {
    return true
  }
  if !@netops.retryable_failure(kind, status) {
    return false
  }
  kind != @netops.ConnectionFailure ||
  options.retry_connection_refused ||
  !message.to_lower().contains("refused")
}

///|
async fn output_for(
  options : WgetOptions,
  url : String,
) -> (@netops.TransferOutput, String, Int64?) {
  match options.output_document {
    Some("-") => (@netops.StandardOutput, "stdout", None)
    Some(path) =>
      (
        @netops.FileOutput(
          path~,
          mode=@netops.Append,
          content_disposition=false,
          remove_on_error=false,
        ),
        path,
        None,
      )
    None => {
      let path = @netops.remote_name(url)
      if options.continue_download && @fs.exists(path) {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        let size = file.size()
        (
          @netops.FileOutput(
            path~,
            mode=@netops.Append,
            content_disposition=options.content_disposition,
            remove_on_error=false,
          ),
          path,
          Some(size),
        )
      } else {
        (
          @netops.FileOutput(
            path~,
            mode=if options.timestamping {
              @netops.Truncate
            } else {
              @netops.Unique
            },
            content_disposition=options.content_disposition,
            remove_on_error=false,
          ),
          path,
          None,
        )
      }
    }
  }
}

///|
async fn wget_observer(
  log : LogDestination,
  interactive : Bool,
  label : String,
  event : @netops.TransferEvent,
) -> Unit {
  match event {
    @netops.Redirected(status~, to~, ..) =>
      log.write("Location: \{to} [following HTTP \{status}]\n")
    @netops.ResponseStarted(status~, reason~, content_length~, ..) => {
      log.write("HTTP request sent, awaiting response... \{status} \{reason}\n")
      match content_length {
        Some(length) => log.write("Length: \{length}\nSaving to: '\{label}'\n")
        None => log.write("Length: unspecified\nSaving to: '\{label}'\n")
      }
    }
    @netops.Progress(received~, content_length~) if interactive =>
      log.write(wget_progress_text(label, received, content_length))
    @netops.Completed(received~, ..) => {
      if interactive {
        log.write("\n")
      }
      log.write("'\{label}' saved [\{received}]\n")
    }
    _ => ()
  }
}

///|
fn wget_progress_text(
  label : String,
  received : Int64,
  content_length : Int64?,
) -> String {
  let detail = match content_length {
    Some(total) if total > 0L => {
      let percent = (received.to_double() * 100.0 / total.to_double())
        .clamp(min=0.0, max=100.0)
        .to_int()
      "\{percent}% [\{received}/\{total}]"
    }
    _ => "\{received} bytes"
  }
  "\r\{label} \{detail}\u{1b}[K"
}

///|
async fn download_one(
  options : WgetOptions,
  log : LogDestination,
  url : String,
) -> Int {
  let (output, label, resume_from) = output_for(options, url) catch {
    err => {
      log.write("wget: \{err}\n")
      return 3
    }
  }
  let headers = options.headers.copy()
  if !headers.any(header => header.name.to_lower() == "user-agent") {
    headers.push(@netops.http_header("User-Agent", "Wget/1.25.0"))
  }
  if !headers.any(header => header.name.to_lower() == "accept") {
    headers.push(@netops.http_header("Accept", "*/*"))
  }
  if options.timestamping && options.output_document is None {
    match timestamp_header(label) {
      Some(header) => headers.push(header)
      None => ()
    }
  }
  let interactive = !options.quiet &&
    options.log_file is None &&
    @platform.terminal_output_enabled(@platform.IfTerminal, @platform.Stderr)
  let mut attempt = 0
  for ;; {
    attempt += 1
    log.write("--  \{url}\n")
    let proxy_url = proxy_for(url, options.no_proxy)
    try
      @netops.transfer(
        url,
        output,
        @netops.transfer_options(
          request_method=options.request_method,
          headers~,
          body=options.body,
          redirects=@netops.FollowRedirects(options.max_redirects),
          verify_tls=!options.no_check_certificate,
          proxy_url?,
          connect_timeout_ms=options.connect_timeout_ms,
          idle_timeout_ms=options.read_timeout_ms,
          fail_on_http_error=true,
          resume_from?,
          keep_output_on_not_modified=options.timestamping,
        ),
        observer=event => wget_observer(log, interactive, label, event),
      )
    catch {
      @netops.TransferError(kind~, message~, status~) => {
        let retryable = wget_can_retry(options, kind, status, message)
        if retryable && (options.tries == 0 || attempt < options.tries) {
          log.write("wget: \{message}; retrying\n")
          if options.retry_delay_ms > 0 {
            @async.sleep(options.retry_delay_ms)
          }
          continue
        }
        log.write("wget: \{message}\n")
        return wget_exit_kind(kind)
      }
      err => {
        log.write("wget: \{err}\n")
        return 1
      }
    } noraise {
      _ => return 0
    }
  }
}

///|
async fn run(options : WgetOptions) -> Int {
  if options.help {
    @stdio.stdout.write(usage())
    return 0
  }
  let log = open_log(options) catch {
    err => {
      @stdio.stderr.write("wget: cannot open log file: \{err}\n")
      return 3
    }
  }
  defer log.close()
  let urls = options.urls.copy()
  for input in options.input_files {
    let values = read_url_file(input) catch {
      err => {
        log.write("wget: cannot read input file '\{input}': \{err}\n")
        return 3
      }
    }
    urls.append(values)
  }
  if urls.is_empty() {
    log.write("wget: missing URL\nUsage: wget [OPTION]... [URL]...\n")
    return 1
  }
  if options.body_options_conflict {
    log.write("wget: --body-data and --body-file are mutually exclusive\n")
    return 1
  }
  match options.body {
    @netops.EmptyBody => ()
    _ if !options.method_explicit => {
      log.write("wget: --body-data/--body-file requires --method\n")
      return 1
    }
    _ => ()
  }
  if options.continue_download && options.output_document is Some(_) {
    log.write("wget: --continue cannot be combined with --output-document\n")
    return 1
  }
  if options.timestamping && options.output_document is Some(_) {
    log.write(
      "wget: --timestamping cannot be combined with --output-document\n",
    )
    return 1
  }
  if options.output_document is Some(path) && path != "-" {
    let file = @fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate) catch {
      err => {
        log.write("\{path}: \{err}\n")
        return 3
      }
    }
    file.close()
  }
  let mut result = 0
  for url in urls {
    let status = download_one(options, log, url)
    if status != 0 {
      result = status
    }
  }
  result
}

///|
async fn main {
  let options = parse_wget_options(@env.args()[1:]) catch {
    WgetUsageError(message) => {
      @stdio.stderr.write("wget: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let status = run(options)
  if status != 0 {
    @sys.exit(status)
  }
}
