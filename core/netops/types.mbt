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
  FollowRedirects(Int)
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
  TlsFailure
  ProxyFailure
  TimeoutFailure
  RedirectFailure
  HttpStatusFailure
  InputFailure
  OutputFailure
  ProtocolFailure
} derive(Eq, Debug)

///|
pub(all) suberror TransferError {
  TransferError(kind~ : TransferErrorKind, message~ : String, status~ : Int?)
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
      )
  }
}

///|
fn HttpMethod::to_runtime(self : HttpMethod) -> @http.RequestMethod {
  match self {
    Get => @http.Get
    Head => @http.Head
    Post => @http.Post
    Put => @http.Put
    Delete => @http.Delete
    Connect => @http.Connect
    Options => @http.Options
    Trace => @http.Trace
    Patch => @http.Patch
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
  request_method : HttpMethod
  headers : Array[HttpHeader]
  body : RequestBody
  redirects : RedirectPolicy
  preserve_method_on_redirect : Bool
  verify_tls : Bool
  proxy_url : String?
  connect_timeout_ms : Int
  idle_timeout_ms : Int
  max_time_ms : Int?
  fail_on_http_error : Bool
  http_error_statuses : Array[Int]
  resume_from : Int64?
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
pub fn transfer_options(
  request_method? : HttpMethod = Get,
  headers? : Array[HttpHeader] = [],
  body? : RequestBody = EmptyBody,
  redirects? : RedirectPolicy = NoRedirects,
  preserve_method_on_redirect? : Bool = false,
  verify_tls? : Bool = true,
  proxy_url? : String,
  connect_timeout_ms? : Int = 30_000,
  idle_timeout_ms? : Int = 30_000,
  max_time_ms? : Int,
  fail_on_http_error? : Bool = false,
  http_error_statuses? : Array[Int] = [],
  resume_from? : Int64,
  keep_output_on_not_modified? : Bool = false,
  cookie_jar? : CookieJar,
  cookie_data? : String,
  custom_cookie_mode? : CustomCookieMode = SeparateFields,
  custom_cookie_cross_origin? : Bool = false,
  basic_credentials? : String,
  basic_preemptive? : Bool = true,
  basic_credential_scope? : BasicCredentialScope = InitialOrigin,
) -> TransferOptions {
  {
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
    status~ : Int,
    reason~ : String,
    headers~ : Array[HttpHeader],
    content_length~ : Int64?
  )
  Redirected(status~ : Int, from~ : String, to~ : String)
  Progress(received~ : Int64, content_length~ : Int64?)
  Completed(received~ : Int64, content_length~ : Int64?)
} derive(Debug)

///|
pub(all) struct TransferResult {
  requested_url : String
  effective_url : String
  status : Int
  reason : String
  headers : Array[HttpHeader]
  received : Int64
  output_path : String?
  redirects : Int
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
