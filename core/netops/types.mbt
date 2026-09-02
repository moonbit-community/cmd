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
