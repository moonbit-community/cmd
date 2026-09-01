///|
pub(all) suberror NetOpError {
  NetOpError(String)
}

///|
pub(all) enum FeedbackMode {
  Quiet
  ErrorsOnly
  Progress
  Summary
} derive(Eq, Debug)

///|
pub(all) struct FetchOptions {
  fail_on_http_error : Bool
  idle_timeout_ms : Int
  feedback : FeedbackMode
  label : String
  diagnostic_path : String?
}

///|
pub fn fetch_options(
  fail_on_http_error : Bool,
  idle_timeout_ms : Int,
  show_progress : Bool,
  label : String,
) -> FetchOptions {
  fetch_options_with_feedback(
    fail_on_http_error,
    idle_timeout_ms,
    if show_progress {
      Progress
    } else {
      Quiet
    },
    label,
  )
}

///|
pub fn fetch_options_with_feedback(
  fail_on_http_error : Bool,
  idle_timeout_ms : Int,
  feedback : FeedbackMode,
  label : String,
  diagnostic_path? : String? = None,
) -> FetchOptions {
  { fail_on_http_error, idle_timeout_ms, feedback, label, diagnostic_path, }
}

///|
fn content_length(response : @http.Response) -> Int64? {
  match response.headers.get("Content-Length") {
    Some(value) => {
      let length = @string.parse_int64(value) catch { _ => return None }
      if length >= 0 {
        Some(length)
      } else {
        None
      }
    }
    None => None
  }
}

///|
priv enum DiagnosticDestination {
  Disabled
  Stderr
  File(@fs.File)
}

///|
async fn write_diagnostic(
  destination : DiagnosticDestination,
  message : String,
) -> Unit {
  match destination {
    Disabled => ()
    Stderr => @stdio.stderr.write(message)
    File(file) => file.write(message)
  }
}

///|
async fn feedback_destination(options : FetchOptions) -> DiagnosticDestination {
  match options.feedback {
    Quiet => Disabled
    ErrorsOnly | Progress | Summary =>
      match options.diagnostic_path {
        Some(path) =>
          File(@fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate))
        None => Stderr
      }
  }
}

///|
async fn feedback_is_interactive(options : FetchOptions) -> Bool {
  match options.feedback {
    Progress if options.diagnostic_path is None =>
      @platform.stderr_is_terminal()
    _ => false
  }
}

///|
fn should_report_progress(
  mode : FeedbackMode,
  interactive : Bool,
  received : Int64,
  now : Int64,
  last_report : Int64,
  is_final : Bool,
) -> Bool {
  match mode {
    Progress if interactive =>
      is_final || received == 0L || now - last_report >= 100L
    Progress | Summary => is_final || received == 0L
    Quiet | ErrorsOnly => false
  }
}

///|
async fn report_progress(
  options : FetchOptions,
  destination : DiagnosticDestination,
  interactive : Bool,
  received : Int64,
  total : Int64?,
  is_final : Bool,
  last_report : Int64,
) -> Int64 {
  let now = @async.now()
  if !should_report_progress(
      options.feedback,
      interactive,
      received,
      now,
      last_report,
      is_final,
    ) {
    return last_report
  }
  if interactive {
    let detail : String = match total {
      Some(length) if length > 0 => {
        let percent = (received.to_double() * 100.0 / length.to_double())
          .clamp(min=0.0, max=100.0)
          .to_int()
        "\{percent}% (\{received}/\{length} bytes)"
      }
      _ => "\{received} bytes"
    }
    let line = "\r\{options.label}: \{detail}\u{1b}[K"
    write_diagnostic(destination, if is_final { line + "\n" } else { line })
  } else if is_final {
    write_diagnostic(
      destination,
      "\{options.label}: downloaded \{received} bytes\n",
    )
  } else if received == 0 {
    write_diagnostic(destination, "\{options.label}: starting download\n")
  }
  now
}

///|
async fn fetch_impl(
  url : String,
  output_path : String?,
  options : FetchOptions,
  destination : DiagnosticDestination,
  interactive : Bool,
) -> Unit {
  let request = @async.with_timeout_opt(options.idle_timeout_ms, () => {
    @http.get_stream(url)
  })
  let (response, body) = match request {
    Some(value) => value
    None =>
      raise NetOpError(
        "request timed out after \{options.idle_timeout_ms} milliseconds",
      )
  }
  defer body.close()
  if options.fail_on_http_error && response.code >= 400 {
    raise NetOpError(
      "server returned HTTP status \{response.code} \{response.reason}",
    )
  }
  let total = content_length(response)
  let mut last_report = report_progress(
    options, destination, interactive, 0L, total, false, 0L,
  )
  let output = match output_path {
    None => None
    Some(path) =>
      Some(@fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate))
  }
  defer (match output {
    Some(file) => file.close()
    None => ()
  })
  let mut received = 0L
  for ;; {
    let chunk = match
      @async.with_timeout_opt(options.idle_timeout_ms, () => {
        body.read_some(max_len=65536)
      }) {
      None =>
        raise NetOpError(
          "request timed out after \{options.idle_timeout_ms} milliseconds",
        )
      Some(None) => break
      Some(Some(value)) => value
    }
    received += chunk.length().to_int64()
    match output {
      Some(file) => file.write(chunk)
      None => @stdio.stdout.write(chunk)
    }
    let now = @async.now()
    if should_report_progress(
        options.feedback,
        interactive,
        received,
        now,
        last_report,
        false,
      ) {
      last_report = report_progress(
        options, destination, interactive, received, total, false, last_report,
      )
    }
  }
  ignore(
    report_progress(
      options, destination, interactive, received, total, true, last_report,
    ),
  )
}

///|
pub async fn fetch_with_options(
  url : String,
  output_path : String?,
  options : FetchOptions,
) -> Unit {
  if options.idle_timeout_ms <= 0 {
    raise NetOpError("idle timeout must be greater than zero")
  }
  let destination = feedback_destination(options) catch {
    err => {
      match options.feedback {
        Quiet => ()
        ErrorsOnly | Progress | Summary => {
          let path = options.diagnostic_path.unwrap_or("stderr")
          @stdio.stderr.write(
            "\{options.label}: cannot open diagnostic destination '\{path}': \{err}\n",
          )
        }
      }
      raise NetOpError("cannot open diagnostic destination")
    }
  }
  defer (match destination {
    File(file) => file.close()
    Disabled | Stderr => ()
  })
  let interactive = feedback_is_interactive(options)
  fetch_impl(url, output_path, options, destination, interactive) catch {
    NetOpError(message) as err => {
      write_diagnostic(destination, "\{options.label}: \{message}\n")
      raise err
    }
    err => {
      let message = "\{err}"
      write_diagnostic(destination, "\{options.label}: \{message}\n")
      raise err
    }
  }
}

///|
/// Backward-compatible fetch entry point with the default 30 second idle
/// timeout while preserving the legacy no-progress behavior.
pub async fn fetch(
  url : String,
  output_path : String?,
  fail_on_http_error : Bool,
) -> Unit {
  fetch_with_options(
    url,
    output_path,
    fetch_options(fail_on_http_error, 30_000, false, "download"),
  )
}
