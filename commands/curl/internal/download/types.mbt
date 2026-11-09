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
  preserve_method_on_redirect : Bool
  verify_tls : Bool
  proxy_url : String?
  connect_timeout_ms : Int32
  idle_timeout_ms : Int32
  max_time_ms : Int32?
  fail_on_http_error : Bool
  resume_from : Int64?
  cookie_jar : CookieJar?
  cookie_data : String?
  basic_user : String?
  basic_password : String?
}

///|
pub fn options(
  utf8_hosts~ : Bool = true,
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
  resume_from? : Int64,
  cookie_jar? : CookieJar,
  cookie_data? : String,
  basic_user? : String,
  basic_password? : String,
) -> Options {
  {
    utf8_hosts,
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
    resume_from,
    cookie_jar,
    cookie_data,
    basic_user,
    basic_password,
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
