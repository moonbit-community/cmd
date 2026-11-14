///|
fn transfer_error(
  kind : TransferErrorKind,
  message : String,
  status? : Int32,
  context? : TransferFailureContext,
) -> TransferError {
  @netops.TransferError(kind~, message~, status~, context~)
}

///|
fn failure_context(
  phase : TransferPhase,
  framing? : ResponseFraming,
  sent_bytes~ : Int64 = 0L,
  received_bytes~ : Int64 = 0L,
  committed_bytes~ : Int64 = 0L,
  write_outcome_uncertain~ : Bool = false,
) -> TransferFailureContext {
  {
    phase,
    framing,
    sent_bytes,
    received_bytes,
    committed_bytes,
    write_outcome_uncertain,
  }
}

///|
fn with_failure_context(
  error : TransferError,
  fallback : TransferFailureContext,
) -> TransferError {
  let @netops.TransferError(kind~, message~, status~, context~) = error
  @netops.TransferError(
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
  let @netops.TransferError(kind~, message~, status~, context~) = error
  if context is Some(context) && context.phase == ResponseBody {
    return @netops.TransferError(
      kind~,
      message~,
      status~,
      context=Some({
        ..context,
        received_bytes,
        committed_bytes,
        write_outcome_uncertain: context.write_outcome_uncertain ||
        write_outcome_uncertain.unwrap_or(kind == OutputFailure),
      }),
    )
  }
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
    | AuthenticationFailure
    | ProtocolFailure => false
    MalformedReplyFailure => false
  }
}
