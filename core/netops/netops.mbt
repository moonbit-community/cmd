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
priv enum DiagnosticDestination {
  DiagnosticsDisabled
  DiagnosticsStderr
  DiagnosticsFile(@fs.File)
}

///|
async fn DiagnosticDestination::write(
  self : DiagnosticDestination,
  message : String,
) -> Unit {
  match self {
    DiagnosticsDisabled => ()
    DiagnosticsStderr => @stdio.stderr.write(message)
    DiagnosticsFile(file) => file.write(message)
  }
}

///|
fn DiagnosticDestination::close(self : DiagnosticDestination) -> Unit {
  match self {
    DiagnosticsFile(file) => file.close()
    DiagnosticsDisabled | DiagnosticsStderr => ()
  }
}

///|
async fn open_diagnostics(options : FetchOptions) -> DiagnosticDestination {
  match options.feedback {
    Quiet => DiagnosticsDisabled
    ErrorsOnly | Progress | Summary =>
      match options.diagnostic_path {
        None => DiagnosticsStderr
        Some(path) =>
          DiagnosticsFile(@fsops.open_output(path, CreateOrTruncate))
      }
  }
}

///|
async fn legacy_progress_observer(
  destination : DiagnosticDestination,
  options : FetchOptions,
  interactive : Bool,
  event : TransferEvent,
) -> Unit {
  match (options.feedback, event) {
    (Progress | Summary, ResponseStarted(..)) =>
      if interactive && options.feedback == Progress {
        destination.write("\r\{options.label}: 0 bytes\u{1b}[K")
      } else {
        destination.write("\{options.label}: starting download\n")
      }
    (Progress, Progress(received~, content_length~)) if interactive => {
      let detail = match content_length {
        Some(total) if total > 0L => {
          let percent = (received.to_double() * 100.0 / total.to_double())
            .clamp(min=0.0, max=100.0)
            .to_int()
          "\{percent}% (\{received}/\{total} bytes)"
        }
        _ => "\{received} bytes"
      }
      destination.write("\r\{options.label}: \{detail}\u{1b}[K")
    }
    (Progress | Summary, Completed(received~, ..)) =>
      if interactive && options.feedback == Progress {
        destination.write("\n")
      } else {
        destination.write("\{options.label}: downloaded \{received} bytes\n")
      }
    _ => ()
  }
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
  let destination = open_diagnostics(options) catch {
    err => {
      let path = options.diagnostic_path.unwrap_or("stderr")
      @stdio.stderr.write(
        "\{options.label}: cannot open diagnostic destination '\{path}': \{err}\n",
      )
      raise NetOpError("cannot open diagnostic destination")
    }
  }
  defer destination.close()
  let interactive = options.feedback == Progress &&
    options.diagnostic_path is None &&
    @platform.terminal_output_enabled(IfTerminal, Stderr)
  let output = match output_path {
    Some(path) =>
      FileOutput(
        path~,
        mode=Truncate,
        content_disposition=false,
        remove_on_error=false,
      )
    None => StandardOutput
  }
  ignore(
    transfer(
      url,
      output,
      transfer_options(
        connect_timeout_ms=options.idle_timeout_ms,
        idle_timeout_ms=options.idle_timeout_ms,
        fail_on_http_error=options.fail_on_http_error,
      ),
      observer=event => {
        legacy_progress_observer(destination, options, interactive, event)
      },
    ) catch {
      TransferError(message~, ..) => {
        destination.write("\{options.label}: \{message}\n")
        raise NetOpError(message)
      }
      err => {
        let message = "\{err}"
        destination.write("\{options.label}: \{message}\n")
        raise NetOpError(message)
      }
    },
  )
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
