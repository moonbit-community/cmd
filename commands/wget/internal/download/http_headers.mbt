///|
fn receive_header(
  event : @netops.ResponseLine,
  pending : Ref[Bytes?],
  truncated : Ref[Bool],
) -> HttpHeader? {
  if event is Status(_, _) {
    truncated.val = false
    pending.val = None
    return None
  }
  let bytes = match event {
    Field(bytes) => {
      if truncated.val {
        return None
      }
      match bytes.to_array().search(b'\x00') {
        Some(end) => {
          truncated.val = true
          bytes[:end].to_owned()
        }
        None => bytes
      }
    }
    _ => b""
  }
  if bytes.length() > 0 && (bytes[0] == b' ' || bytes[0] == b'\t') {
    if pending.val is Some(previous) {
      let joined = Buffer()
      for byte in previous {
        joined.write_byte(
          if byte == b'\r' || byte == b'\n' {
            b' '
          } else {
            byte
          },
        )
      }
      joined.write_bytes(bytes)
      pending.val = Some(joined.to_bytes())
    }
    return None
  }
  let admitted = pending.val
  pending.val = if event is Field(_) { Some(bytes) } else { None }
  match admitted {
    Some(raw) =>
      @netops.parse_header_line(
        cookie_bytes(
          cookie_text(raw).trim_end(chars=" \t\r\n\u000b\u000c").to_owned(),
        ),
      )
    None => None
  }
}
