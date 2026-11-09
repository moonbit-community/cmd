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
async fn open_log(options : Options) -> LogDestination {
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
fn two_digits(value : Int32) -> String {
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
fn http_month(value : Int32) -> String {
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
fn proxy_for(
  url : String,
  disabled : Bool,
  utf8_hosts : Bool,
  lookup_env~ : (String) -> String? = @env.get_env_var,
) -> String? {
  if disabled {
    return None
  }
  let no_proxy = match lookup_env("NO_PROXY") {
    Some(value) => Some(value)
    None => lookup_env("no_proxy")
  }
  if @download.proxy_bypassed(url, no_proxy, utf8_hosts~) {
    return None
  }
  let scheme_name = if url.to_lower().has_prefix("https://") {
    "https_proxy"
  } else {
    "http_proxy"
  }
  match lookup_env(scheme_name) {
    Some(value) => Some(value)
    None =>
      match lookup_env(scheme_name.to_upper()) {
        Some(value) => Some(value)
        None => lookup_env("all_proxy")
      }
  }
}

///|
fn exit_code(kind : @netops.TransferErrorKind) -> Int32 {
  match kind {
    @netops.HttpStatusFailure => 8
    @netops.AuthenticationFailure => 6
    @netops.TlsFailure => 5
    @netops.InputFailure | @netops.RewindFailure | @netops.OutputFailure => 3
    @netops.UnsupportedProtocol | @netops.InvalidUrl => 1
    @netops.InvalidMethod | @netops.ProtocolFailure | @netops.RedirectFailure =>
      7
    @netops.ConnectionFailure
    | @netops.ReceiveFailure
    | @netops.EmptyReplyFailure
    | @netops.PartialBodyFailure
    | @netops.ProxyFailure
    | @netops.TimeoutFailure => 4
  }
}

///|
fn can_retry(
  options : Options,
  kind : @netops.TransferErrorKind,
  status : Int32?,
  message : String,
) -> Bool {
  let retry_http = match status {
    Some(value) => options.retry_http_statuses.contains(value)
    None => false
  }
  if retry_http {
    return true
  }
  if !@download.retryable_failure(kind, status) {
    return false
  }
  kind != @netops.ConnectionFailure ||
  options.retry_connection_refused ||
  !message.to_lower().contains("refused")
}

///|
async fn output_for(
  options : Options,
  url : String,
  selected_name? : String,
  defer_resume~ : Bool = false,
) -> (@download.TransferOutput, String, Int64?) {
  match options.output_document {
    Some("-") => (@download.StandardOutput, "stdout", None)
    Some(path) =>
      (
        @download.FileOutput(
          path~,
          mode=@download.Append,
          content_disposition=false,
          remove_on_error=false,
        ),
        path,
        None,
      )
    None => {
      let path = selected_name.unwrap_or_else(() => @download.remote_name(url))
      let disposition = options.content_disposition && selected_name is None
      if options.continue_download && !defer_resume && @fs.exists(path) {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        let size = file.size()
        (
          @download.FileOutput(
            path~,
            mode=@download.Append,
            content_disposition=disposition,
            remove_on_error=false,
          ),
          path,
          Some(size),
        )
      } else {
        (
          @download.FileOutput(
            path~,
            mode=if options.timestamping {
              @download.Truncate
            } else {
              @download.Unique
            },
            content_disposition=disposition,
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
priv struct DownloadProgress {
  mut output : @download.TransferOutput
  mut downloaded : Int64
  mut response_offset : Int64
}

///|
fn DownloadProgress::observe(
  self : DownloadProgress,
  event : @download.TransferEvent,
) -> Unit {
  match event {
    @download.OutputStarted(path~, response_offset~) => {
      self.response_offset = response_offset
      if path is Some(path) {
        // Retain the actual unique or Content-Disposition name across attempts.
        self.output = @download.FileOutput(
          path~,
          mode=@download.Append,
          content_disposition=false,
          remove_on_error=false,
        )
      }
    }
    @download.Progress(received~, ..) =>
      self.downloaded = self.downloaded.max(self.response_offset + received)
    _ => ()
  }
}

///|
async fn observe_transfer(
  log : LogDestination,
  interactive : Bool,
  label : String,
  event : @download.TransferEvent,
) -> Unit {
  match event {
    @download.Redirected(status~, to~, ..) =>
      log.write("Location: \{to} [following HTTP \{status}]\n")
    @download.ResponseStarted(status~, reason~, content_length~, ..) => {
      log.write("HTTP request sent, awaiting response... \{status} \{reason}\n")
      match content_length {
        Some(length) => log.write("Length: \{length}\nSaving to: '\{label}'\n")
        None => log.write("Length: unspecified\nSaving to: '\{label}'\n")
      }
    }
    @download.Progress(received~, content_length~) if interactive =>
      log.write(progress_text(label, received, content_length))
    @download.Completed(received~, ..) => {
      if interactive {
        log.write("\n")
      }
      log.write("'\{label}' saved [\{received}]\n")
    }
    _ => ()
  }
}

///|
fn progress_text(
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
  options : Options,
  log : LogDestination,
  url : String,
  jar : @download.CookieJar?,
  basic_hosts~ : Map[String, Bool] = Map([]),
  lookup_env~ : (String) -> String? = @env.get_env_var,
) -> Int32 {
  let mut discover_name = options.continue_download &&
    options.content_disposition &&
    options.output_document is None &&
    options.request_method == @netops.Get
  let (output, initial_label, resume_from) = output_for(
    options,
    url,
    defer_resume=discover_name,
  ) catch {
    err => {
      log.write("wget: \{err}\n")
      return 3
    }
  }
  let mut label = initial_label
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
  let progress : DownloadProgress = {
    output,
    downloaded: resume_from.unwrap_or(0L),
    response_offset: 0L,
  }
  let mut attempt = 0
  for ;; {
    attempt += 1
    log.write("--  \{url}\n")
    let proxy_url = proxy_for(
      url,
      options.no_proxy,
      options.utf8_hosts,
      lookup_env~,
    )
    try {
      let mut request_options = @download.options(
        utf8_hosts=options.utf8_hosts,
        request_method=options.request_method,
        headers~,
        body=options.body,
        redirects=@download.FollowRedirects(options.max_redirects),
        verify_tls=!options.no_check_certificate,
        proxy_url?,
        connect_timeout_ms=options.connect_timeout_ms,
        idle_timeout_ms=options.read_timeout_ms,
        fail_on_http_error=true,
        http_error_statuses=if options.timestamping { [] } else { [304] },
        resume_from?=if progress.downloaded > 0L {
          Some(progress.downloaded)
        } else {
          None
        },
        keep_output_on_not_modified=options.timestamping,
        cookie_jar?=jar,
        basic_user?=options.user,
        basic_password?=options.password,
        basic_preemptive=options.auth_no_challenge,
        basic_challenged_hosts=basic_hosts,
      )
      if discover_name {
        let discovery = @download.transfer(url, @download.DiscardOutput, {
          ..request_options,
          request_method: @netops.Head,
          body: @netops.EmptyBody,
          resume_from: None,
        })
        let selected = discovery
          .content_disposition_filename()
          .unwrap_or(initial_label)
        let (selected_output, selected_label, selected_resume) = output_for(
          options,
          url,
          selected_name=selected,
        ) catch {
          error => {
            log.write("wget: \{error}\n")
            return 3
          }
        }
        progress.output = selected_output
        progress.downloaded = selected_resume.unwrap_or(0L)
        progress.response_offset = 0L
        label = selected_label
        request_options = { ..request_options, resume_from: selected_resume, }
        discover_name = false
      }
      @download.transfer(url, progress.output, request_options, observer=event => {
        progress.observe(event)
        observe_transfer(log, interactive, label, event)
      })
    } catch {
      @netops.TransferError(kind~, message~, status~, ..) => {
        let retryable = can_retry(options, kind, status, message)
        if retryable &&
          !(options.body is @netops.StdinBody) &&
          (options.tries == 0 || attempt < options.tries) {
          log.write("wget: \{message}; retrying\n")
          if options.retry_delay_ms > 0 {
            @async.sleep(options.retry_delay_ms)
          }
          continue
        }
        log.write("wget: \{message}\n")
        return exit_code(kind)
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
async fn run(
  options : Options,
  lookup_env~ : (String) -> String? = @env.get_env_var,
) -> Int32 {
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
  let jar = if options.cookies {
    Some(@download.CookieJar::new())
  } else {
    None
  }
  if jar is Some(jar) && options.load_cookies is Some(path) {
    jar.load(path) catch {
      err => log.write("wget: cannot read cookie jar '\{path}': \{err}\n")
    }
  }
  let mut result = 0
  let basic_hosts : Map[String, Bool] = Map([])
  for url in urls {
    let status = download_one(options, log, url, jar, basic_hosts~, lookup_env~)
    if status != 0 && (result == 0 || status < result) {
      result = status
    }
  }
  if jar is Some(jar) && options.save_cookies is Some(path) {
    jar.save(path, include_session=options.keep_session_cookies) catch {
      err => log.write("wget: cannot write cookie jar '\{path}': \{err}\n")
    }
  }
  result
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("wget 0.2.5\n")
    return
  }
  let options = parse_options(@env.args()[1:]) catch {
    UsageError(message) => {
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
