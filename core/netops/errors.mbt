///|
fn transfer_error(
  kind : TransferErrorKind,
  message : String,
  status? : Int32,
  context? : TransferFailureContext,
) -> TransferError {
  TransferError(kind~, message~, status~, context~)
}

///|
fn failure_context(
  phase : TransferPhase,
  framing? : ResponseFraming,
  received_bytes~ : Int64 = 0L,
  committed_bytes~ : Int64 = 0L,
  write_outcome_uncertain~ : Bool = false,
) -> TransferFailureContext {
  { phase, framing, received_bytes, committed_bytes, write_outcome_uncertain, }
}

///|
fn with_failure_context(
  error : TransferError,
  fallback : TransferFailureContext,
) -> TransferError {
  let TransferError(kind~, message~, status~, context~) = error
  TransferError(
    kind~,
    message~,
    status~,
    context=Some(context.unwrap_or(fallback)),
  )
}

///|
fn response_body_failure(
  error : TransferError,
  framing : ResponseFraming,
  received_bytes~ : Int64,
  committed_bytes~ : Int64,
  write_outcome_uncertain? : Bool,
) -> TransferError {
  let TransferError(kind~, ..) = error
  with_failure_context(
    error,
    failure_context(
      ResponseBody,
      framing~,
      received_bytes~,
      committed_bytes~,
      write_outcome_uncertain=write_outcome_uncertain.unwrap_or(
        kind == OutputFailure,
      ),
    ),
  )
}

///|
fn timeout_for(
  options : TransferOptions,
  started : Int64,
  phase_timeout : Int32,
  phase : String,
) -> Int32 raise TransferError {
  match options.max_time_ms {
    None => phase_timeout
    Some(maximum) => {
      let remaining = maximum.to_int64() - (@async.now() - started)
      if remaining <= 0L {
        raise transfer_error(
          TimeoutFailure,
          "operation timed out during \{phase}",
        )
      }
      phase_timeout.min(remaining.min(2147483647L).to_int())
    }
  }
}

///|
fn timeout_message(phase : String, timeout : Int32) -> TransferError {
  transfer_error(
    TimeoutFailure,
    "operation timed out after \{timeout} milliseconds during \{phase}",
  )
}

///|
pub fn retryable_failure(kind : TransferErrorKind, status : Int32?) -> Bool {
  match kind {
    ConnectionFailure
    | EmptyReplyFailure
    | ReceiveFailure
    | PartialBodyFailure
    | TimeoutFailure => true
    HttpStatusFailure =>
      match status {
        Some(408 | 429 | 500 | 502 | 503 | 504) => true
        _ => false
      }
    InvalidUrl
    | UnsupportedProtocol
    | InvalidMethod
    | TlsFailure
    | ProxyFailure
    | RedirectFailure
    | InputFailure
    | RewindFailure
    | OutputFailure
    | ProtocolFailure => false
  }
}
