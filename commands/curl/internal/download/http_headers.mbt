///|
async fn admit_header(
  raw : Bytes,
  field~ : Bool,
  url : ParsedUrl,
  jar : CookieJar?,
  observer : (async (TransferEvent) -> Unit)?,
) -> HttpHeader? {
  let mut end = raw.length()
  if end > 0 && raw[end - 1] == b'\n' {
    end -= 1
  }
  if end > 0 && raw[end - 1] == b'\r' {
    end -= 1
  }
  let bytes = raw[:end].to_owned()
  guard !bytes.to_array().contains(b'\x00') else {
    raise transfer_error(@netops.MalformedReplyFailure, "Nul byte in header")
  }
  guard !bytes.to_array().contains(b'\r') else {
    raise transfer_error(
      @netops.MalformedReplyFailure,
      "Carriage return found in header",
    )
  }
  let admitted = if field {
    guard @netops.parse_header_line(bytes) is Some(field) else {
      raise transfer_error(
        @netops.MalformedReplyFailure,
        "Header without colon",
      )
    }
    if field.name.to_lower() == "set-cookie" && jar is Some(jar) {
      if parse_cookie_octets(cookie_text(field.bytes())) is Some(cookie) {
        jar.receive(url, [cookie], @fsops.current_timestamp().seconds)
      }
    }
    Some(field)
  } else {
    None
  }
  emit(observer, ResponseHeader(raw))
  admitted
}

///|
async fn receive_header(
  event : @netops.ResponseLine,
  url : ParsedUrl,
  jar : CookieJar?,
  observer : (async (TransferEvent) -> Unit)?,
  pending : Ref[Bytes?],
) -> HttpHeader? {
  if event is Status(_, bytes) &&
    (bytes.is_empty() || bytes[bytes.length() - 1] != b'\n') {
    raise transfer_error(@netops.EmptyReplyFailure, "Empty reply from server")
  }
  let raw = match event {
    Status(_, bytes) | Field(bytes) | End(bytes) => bytes
    Eof => {
      // Curl's transfer cleanup exposes a buffered tail without parsing it.
      if pending.val is Some(previous) {
        emit(observer, ResponseHeader(previous))
      }
      pending.val = None
      return None
    }
  }
  if event is Field(_) &&
    raw.length() > 0 &&
    (raw[0] == b' ' || raw[0] == b'\t') {
    if pending.val is Some(previous) {
      let left = cookie_text(previous).trim_end(chars="\r\n \t")
      let right = cookie_text(raw).trim_start(chars=" \t")
      pending.val = Some(cookie_bytes(left.to_owned() + " " + right.to_owned()))
      return None
    }
  }
  let admitted = match pending.val {
    Some(previous) => admit_header(previous, field=true, url, jar, observer)
    None => None
  }
  pending.val = None
  match event {
    Field(_) => pending.val = Some(raw)
    _ => ignore(admit_header(raw, field=false, url, jar, observer))
  }
  admitted
}
