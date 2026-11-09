///|
#derive(Eq, Debug)
pub(all) enum RedirectPolicy {
  NoRedirects
  FollowRedirects(Int32)
}

///|
#derive(Eq, Debug)
pub(all) enum TransferFileMode {
  Truncate
  Append
  Unique
}

///|
#derive(Debug)
pub(all) enum TransferOutput {
  StandardOutput
  DiscardOutput
  FileOutput(
    path~ : String,
    mode~ : TransferFileMode,
    content_disposition~ : Bool,
    remove_on_error~ : Bool
  )
}

///|
pub(all) struct Options {
  utf8_hosts : Bool
  request_method : HttpMethod
  headers : Array[HttpHeader]
  body : RequestBody
  redirects : RedirectPolicy
  verify_tls : Bool
  proxy_url : String?
  connect_timeout_ms : Int32
  idle_timeout_ms : Int32
  fail_on_http_error : Bool
  http_error_statuses : Array[Int32]
  resume_from : Int64?
  keep_output_on_not_modified : Bool
  cookie_jar : CookieJar?
  basic_user : String?
  basic_password : String?
  basic_preemptive : Bool
  basic_challenged_hosts : Map[String, Bool]
}

///|
pub fn options(
  utf8_hosts~ : Bool = true,
  request_method~ : HttpMethod = Get,
  headers~ : Array[HttpHeader] = [],
  body~ : RequestBody = EmptyBody,
  redirects~ : RedirectPolicy = NoRedirects,
  verify_tls~ : Bool = true,
  proxy_url? : String,
  connect_timeout_ms~ : Int32 = 30_000,
  idle_timeout_ms~ : Int32 = 30_000,
  fail_on_http_error~ : Bool = false,
  http_error_statuses~ : Array[Int32] = [],
  resume_from? : Int64,
  keep_output_on_not_modified~ : Bool = false,
  cookie_jar? : CookieJar,
  basic_user? : String,
  basic_password? : String,
  basic_preemptive~ : Bool = true,
  basic_challenged_hosts~ : Map[String, Bool] = Map([]),
) -> Options {
  {
    utf8_hosts,
    request_method,
    headers,
    body,
    redirects,
    verify_tls,
    proxy_url,
    connect_timeout_ms,
    idle_timeout_ms,
    fail_on_http_error,
    http_error_statuses,
    resume_from,
    keep_output_on_not_modified,
    cookie_jar,
    basic_user,
    basic_password,
    basic_preemptive,
    basic_challenged_hosts,
  }
}

///|
#derive(Debug)
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
}

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
fn TransferResult::header(self : TransferResult, name : String) -> String? {
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
pub extend RedirectPolicy with Eq::{not_equal, equal}

///|
pub extend RedirectPolicy with @debug.Debug::{to_repr}

///|
pub extend TransferFileMode with Eq::{not_equal, equal}

///|
pub extend TransferFileMode with @debug.Debug::{to_repr}

///|
pub extend TransferOutput with @debug.Debug::{to_repr}

///|
pub extend TransferEvent with @debug.Debug::{to_repr}
