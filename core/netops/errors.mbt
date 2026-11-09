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
  let TransferError(kind~, message~, status~, context~) = error
  TransferError(
    kind~,
    message~,
    status~,
    context=Some(context.unwrap_or(fallback)),
  )
}

///|
fn timeout_error(phase : String, timeout : Int32) -> TransferError {
  transfer_error(
    TimeoutFailure,
    "operation timed out after \{timeout} milliseconds during \{phase}",
  )
}
