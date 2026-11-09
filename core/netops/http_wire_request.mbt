///|
fn HttpMethod::wire_name(self : HttpMethod) -> String {
  match self {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
fn wire_hex(length : Int32) -> String {
  if length < 16 {
    return "0123456789abcdef"[length:length + 1].to_owned()
  }
  wire_hex(length / 16) + wire_hex(length % 16)
}
