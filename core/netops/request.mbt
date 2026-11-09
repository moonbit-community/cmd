///|
pub fn validate_headers(
  headers : ArrayView[HttpHeader],
) -> Unit raise TransferError {
  for header in headers {
    if !wire_token(header.name) ||
      header.value.contains("\r") ||
      header.value.contains("\n") {
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

///|
fn HeaderFields::contains(self : HeaderFields, name : String) -> Bool {
  self.get(name) is Some(_)
}
