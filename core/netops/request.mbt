///|
/// Split an HTTP field without interpreting its value octets. A caller owns
/// admission of non-framing metadata; the transport validates framing later.
pub fn parse_header_line(line : Bytes) -> HttpHeader? {
  guard line.to_array().search(b':') is Some(colon) else { return None }
  let name = @utf8.decode_lossy(line[:colon].to_owned())
  let mut start = colon + 1
  let mut end = line.length()
  while start < end && (line[start] == b' ' || line[start] == b'\t') {
    start += 1
  }
  while end > start && (line[end - 1] == b' ' || line[end - 1] == b'\t') {
    end -= 1
  }
  Some(http_header_bytes(name, line[start:end].to_owned()))
}

///|
pub fn validate_headers(
  headers : ArrayView[HttpHeader],
) -> Unit raise TransferError {
  for header in headers {
    let bytes = header.bytes()
    if !wire_token(header.name) ||
      (header.octets is None && header.value.contains("\r")) ||
      bytes.to_array().contains(b'\n') ||
      header.value != @utf8.decode_lossy(bytes) {
      raise transfer_error(
        ProtocolFailure,
        "invalid HTTP header '\{header.name}'",
      )
    }
    let name = header.name.to_lower()
    if name == "host" || name == "transfer-encoding" {
      raise transfer_error(
        ProtocolFailure,
        "HTTP header '\{header.name}' is managed by the transport",
      )
    }
  }
}

///|
priv struct HeaderFields {
  fields : Array[HttpHeader]
}

///|
fn HeaderFields::get(self : HeaderFields, name : String) -> String? {
  let name = name.to_lower()
  for header in self.fields {
    if header.name.to_lower() == name {
      return Some(header.value)
    }
  }
  None
}
