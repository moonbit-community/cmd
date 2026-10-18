///|
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
} derive(Eq, Debug)

///|
pub(all) struct HttpHeader {
  name : String
  value : String
} derive(Eq, Debug)

///|
pub fn http_header(name : String, value : String) -> HttpHeader {
  { name, value, }
}

///|
pub(all) enum RequestBody {
  EmptyBody
  BytesBody(Bytes)
  FileBody(String)
  StdinBody
} derive(Debug)

///|
pub(all) enum RedirectPolicy {
  NoRedirects
  FollowRedirects(Int32)
} derive(Eq, Debug)

///|
/// Scope of explicitly supplied Basic credentials, independent of custom headers.
pub(all) enum BasicCredentialScope {
  InitialOrigin
  AllOrigins
} derive(Eq, Debug)

///|
pub(all) enum TransferFileMode {
  Truncate
  Append
  Unique
} derive(Eq, Debug)

///|
pub(all) enum TransferProfile {
  StrictProfile
  CurlProfile
  WgetProfile
} derive(Eq, Debug)

///|
pub extend TransferProfile with Eq::{equal, not_equal}

///|
pub extend TransferProfile with @debug.Debug::{to_repr}

///|
pub(all) enum TransferOutput {
  StandardOutput
  DiscardOutput
  FileOutput(
    path~ : String,
    mode~ : TransferFileMode,
    content_disposition~ : Bool,
    remove_on_error~ : Bool
  )
} derive(Debug)

///|
pub(all) enum TransferErrorKind {
  InvalidUrl
  UnsupportedProtocol
  InvalidMethod
  ConnectionFailure
  EmptyReplyFailure
  ReceiveFailure
  PartialBodyFailure
  TlsFailure
  ProxyFailure
  TimeoutFailure
  RedirectFailure
  HttpStatusFailure
  InputFailure
  RewindFailure
  OutputFailure
  ProtocolFailure
} derive(Eq, Debug)

///|
pub(all) enum TransferPhase {
  Connection
  Request
  ResponseHeaders
  ResponseBody
} derive(Eq, Debug)

///|
pub extend TransferPhase with Eq::{equal, not_equal}

///|
pub extend TransferPhase with @debug.Debug::{to_repr}

///|
pub(all) enum ResponseFraming {
  Bodyless
  FixedLength(Int64)
  Chunked
  CloseDelimited
} derive(Eq, Debug)

///|
pub extend ResponseFraming with Eq::{equal, not_equal}

///|
pub extend ResponseFraming with @debug.Debug::{to_repr}

///|
/// Counts include only bytes returned by the reader and completed sink writes.
/// A failed write may have additional effects that the Writer API cannot report.
pub(all) struct TransferFailureContext {
  phase : TransferPhase
  framing : ResponseFraming?
  received_bytes : Int64
  committed_bytes : Int64
  write_outcome_uncertain : Bool
} derive(Eq, Debug)

///|
pub extend TransferFailureContext with Eq::{equal, not_equal}

///|
pub extend TransferFailureContext with @debug.Debug::{to_repr}

///|
pub(all) suberror TransferError {
  TransferError(
    kind~ : TransferErrorKind,
    message~ : String,
    status~ : Int32?,
    context~ : TransferFailureContext?
  )
} derive(Eq, Debug)

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
/// How an explicit Cookie field interacts with cookies selected from the jar.
pub(all) enum CustomCookieMode {
  SeparateFields
  ReplaceStored
}

///|
pub(all) struct TransferOptions {
  profile : TransferProfile
  request_method : HttpMethod
  headers : Array[HttpHeader]
  body : RequestBody
  redirects : RedirectPolicy
  preserve_method_on_redirect : Bool
  verify_tls : Bool
  proxy_url : String?
  connect_timeout_ms : Int32
  idle_timeout_ms : Int32
  max_time_ms : Int32?
  fail_on_http_error : Bool
  http_error_statuses : Array[Int32]
  resume_from : Int64?
  resume_skip_existing : Bool
  keep_output_on_not_modified : Bool
  cookie_jar : CookieJar?
  cookie_data : String?
  custom_cookie_mode : CustomCookieMode
  custom_cookie_cross_origin : Bool
  basic_credentials : String?
  basic_preemptive : Bool
  basic_credential_scope : BasicCredentialScope
}

///|
/// With `resume_skip_existing`, a full response to an ignored Range is consumed
/// past the retained prefix before appending new bytes. File output must append.
pub fn transfer_options(
  profile~ : TransferProfile = StrictProfile,
  request_method~ : HttpMethod = Get,
  headers~ : Array[HttpHeader] = [],
  body~ : RequestBody = EmptyBody,
  redirects~ : RedirectPolicy = NoRedirects,
  preserve_method_on_redirect~ : Bool = false,
  verify_tls~ : Bool = true,
  proxy_url? : String,
  connect_timeout_ms~ : Int32 = 30_000,
  idle_timeout_ms~ : Int32 = 30_000,
  max_time_ms? : Int32,
  fail_on_http_error~ : Bool = false,
  http_error_statuses~ : Array[Int32] = [],
  resume_from? : Int64,
  resume_skip_existing~ : Bool = false,
  keep_output_on_not_modified~ : Bool = false,
  cookie_jar? : CookieJar,
  cookie_data? : String,
  custom_cookie_mode~ : CustomCookieMode = SeparateFields,
  custom_cookie_cross_origin~ : Bool = false,
  basic_credentials? : String,
  basic_preemptive~ : Bool = true,
  basic_credential_scope~ : BasicCredentialScope = InitialOrigin,
) -> TransferOptions {
  {
    profile,
    request_method,
    headers,
    body,
    redirects,
    preserve_method_on_redirect,
    verify_tls,
    proxy_url,
    connect_timeout_ms,
    idle_timeout_ms,
    max_time_ms,
    fail_on_http_error,
    http_error_statuses,
    resume_from,
    resume_skip_existing,
    keep_output_on_not_modified,
    cookie_jar,
    cookie_data,
    custom_cookie_mode,
    custom_cookie_cross_origin,
    basic_credentials,
    basic_preemptive,
    basic_credential_scope,
  }
}

///|
pub(all) enum TransferEvent {
  ResponseStarted(
    url~ : String,
    status~ : Int32,
    reason~ : String,
    headers~ : Array[HttpHeader],
    content_length~ : Int64?
  )
  Redirected(status~ : Int32, from~ : String, to~ : String)
  OutputStarted(path~ : String?, response_offset~ : Int64)
  Progress(received~ : Int64, content_length~ : Int64?)
  Completed(received~ : Int64, content_length~ : Int64?)
} derive(Debug)

///|
pub(all) struct TransferResult {
  requested_url : String
  effective_url : String
  status : Int32
  reason : String
  headers : Array[HttpHeader]
  received : Int64
  output_path : String?
  redirects : Int32
}

///|
pub fn TransferResult::header(self : TransferResult, name : String) -> String? {
  let normalized = name.to_lower()
  for header in self.headers {
    if header.name.to_lower() == normalized {
      return Some(header.value)
    }
  }
  None
}

///|
pub fn TransferResult::content_disposition_filename(
  self : TransferResult,
) -> String? {
  match self.header("Content-Disposition") {
    Some(value) => content_disposition_filename(value).map(@fsops.basename)
    None => None
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
pub extend RedirectPolicy with Eq::{not_equal, equal}

///|
pub extend RedirectPolicy with @debug.Debug::{to_repr}

///|
pub extend BasicCredentialScope with Eq::{not_equal, equal}

///|
pub extend BasicCredentialScope with @debug.Debug::{to_repr}

///|
pub extend TransferFileMode with Eq::{not_equal, equal}

///|
pub extend TransferFileMode with @debug.Debug::{to_repr}

///|
pub extend TransferOutput with @debug.Debug::{to_repr}

///|
pub extend TransferErrorKind with Eq::{not_equal, equal}

///|
pub extend TransferErrorKind with @debug.Debug::{to_repr}

///|
pub extend TransferError with Eq::{not_equal, equal}

///|
pub extend TransferError with @debug.Debug::{to_repr}

///|
pub extend TransferEvent with @debug.Debug::{to_repr}
