///|
#derive(Eq, Debug)
pub(all) enum HttpMethod {
  Get
  Head
  Post
  Put
  Delete
  Connect
  Options
  Trace
  Patch
}

///|
#derive(Debug)
pub(all) struct HttpHeader {
  name : String
  value : String
  octets : Bytes?
}

///|
pub fn http_header(name : String, value : String) -> HttpHeader {
  { name, value, octets: None, }
}

///|
/// Keep policy-admitted field octets independently of their readable UTF-8
/// projection. Unlike text fields, raw fields can contain a carriage return;
/// the owning HTTP dialect admits it. A line feed is never admitted for output.
pub fn http_header_bytes(name : String, value : Bytes) -> HttpHeader {
  { name, value: @utf8.decode_lossy(value), octets: Some(value), }
}

///|
pub fn HttpHeader::bytes(self : HttpHeader) -> Bytes {
  self.octets.unwrap_or_else(() => @utf8.encode(self.value))
}

///|
pub impl Eq for HttpHeader with fn equal(self, other) {
  self.name == other.name && self.bytes() == other.bytes()
}

///|
#derive(Debug)
pub(all) enum RequestBody {
  EmptyBody
  BytesBody(Bytes)
  FileBody(String)
  StdinBody
}

///|
#derive(Eq, Debug)
pub(all) enum TransferErrorKind {
  InvalidUrl
  UnsupportedProtocol
  InvalidMethod
  ConnectionFailure
  EmptyReplyFailure
  ReceiveFailure
  MalformedReplyFailure
  PartialBodyFailure
  TlsFailure
  ProxyFailure
  TimeoutFailure
  RedirectFailure
  HttpStatusFailure
  AuthenticationFailure
  InputFailure
  RewindFailure
  OutputFailure
  ProtocolFailure
}

///|
#derive(Eq, Debug)
pub(all) enum TransferPhase {
  Connection
  Request
  ResponseHeaders
  ResponseBody
}

///|
pub extend TransferPhase with Eq::{equal, not_equal}

///|
pub extend TransferPhase with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum ResponseFraming {
  Bodyless
  FixedLength(Int64)
  Chunked
  CloseDelimited
}

///|
pub extend ResponseFraming with Eq::{equal, not_equal}

///|
pub extend ResponseFraming with @debug.Debug::{to_repr}

///|
/// Counts include only bytes returned by the reader and completed sink writes.
/// A failed write may have additional effects that the Writer API cannot report.
#derive(Eq, Debug)
pub(all) struct TransferFailureContext {
  phase : TransferPhase
  framing : ResponseFraming?
  sent_bytes : Int64
  received_bytes : Int64
  committed_bytes : Int64
  write_outcome_uncertain : Bool
}

///|
pub extend TransferFailureContext with Eq::{equal, not_equal}

///|
pub extend TransferFailureContext with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) suberror TransferError {
  TransferError(
    kind~ : TransferErrorKind,
    message~ : String,
    status~ : Int32?,
    context~ : TransferFailureContext?
  )
}

///|
pub fn parse_http_method(value : String) -> HttpMethod raise TransferError {
  match value.to_upper() {
    "GET" => Get
    "HEAD" => Head
    "POST" => Post
    "PUT" => Put
    "DELETE" => Delete
    "CONNECT" => Connect
    "OPTIONS" => Options
    "TRACE" => Trace
    "PATCH" => Patch
    _ =>
      raise TransferError(
        kind=InvalidMethod,
        message="unsupported HTTP method '\{value}'",
        status=None,
        context=None,
      )
  }
}

///|
pub extend HttpMethod with Eq::{not_equal, equal}

///|
pub extend HttpMethod with @debug.Debug::{to_repr}

///|
pub extend HttpHeader with Eq::{not_equal, equal}

///|
pub extend HttpHeader with @debug.Debug::{to_repr}

///|
pub extend RequestBody with @debug.Debug::{to_repr}

///|
pub extend TransferErrorKind with Eq::{not_equal, equal}

///|
pub extend TransferErrorKind with @debug.Debug::{to_repr}

///|
pub extend TransferError with Eq::{not_equal, equal}

///|
pub extend TransferError with @debug.Debug::{to_repr}
