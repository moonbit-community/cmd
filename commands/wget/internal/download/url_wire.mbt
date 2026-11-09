///|
fn unsafe_request_character(character : Char) -> Bool {
  character <= ' ' || character == '\u007f'
}

///|
fn decode_host(value : String) -> String raise TransferError {
  let input = @utf8.encode(value)
  let output = Buffer()
  let mut index = 0
  while index < input.length() {
    if input[index] == b'%' &&
      index + 2 < input.length() &&
      @netops.hex_value(input[index + 1].to_char()) is Some(high) &&
      @netops.hex_value(input[index + 2].to_char()) is Some(low) {
      let byte = ((high << 4) | low).to_byte()
      if byte == b'\x00' {
        output.write_bytes(b"%00")
      } else {
        guard byte >= b' ' && byte != b'\x7f' else {
          raise invalid_url("URL host contains an escaped control character")
        }
        output.write_byte(byte)
      }
      index += 3
    } else {
      output.write_byte(input[index])
      index += 1
    }
  }
  @utf8.decode(output.to_bytes()) catch {
    _ => raise invalid_url("URL host is not valid UTF-8")
  }
}

///|
fn ParsedUrl::transfer_host(
  self : ParsedUrl,
  utf8_hosts : Bool,
) -> String raise TransferError {
  if self.host_normalized || self.ip_literal {
    return self.host
  }
  let decoded = decode_host(self.host)
  if decoded.iter().all(character => character.to_int() < 128) {
    return cookie_ascii_lower(decoded)
  }
  if !utf8_hosts {
    if !self.host.iter().all(character => character.to_int() < 128) {
      return cookie_ascii_lower(decoded)
    }
  }
  @netops.idna_host(decoded) catch {
    _ => decoded
  }
}

///|
fn request_component(value : String) -> String {
  let result = StringBuilder()
  for character in value {
    if unsafe_request_character(character) {
      let code = character.to_int()
      result.write_char('%')
      result.write_char("0123456789ABCDEF".get_char(code >> 4).unwrap())
      result.write_char("0123456789ABCDEF".get_char(code & 15).unwrap())
    } else {
      result.write_char(character)
    }
  }
  result.to_string()
}

///|
fn ParsedUrl::request_host(self : ParsedUrl) -> String {
  let host = if self.host.contains(":") && !self.ip_literal {
    "[" + self.host + "]"
  } else {
    self.host
  }
  match self.port {
    Some(port) if port != (if self.scheme == "https" { 443 } else { 80 }) =>
      host + ":" + port.to_string()
    _ => host
  }
}

///|
fn ParsedUrl::for_transfer(
  self : ParsedUrl,
  utf8_hosts~ : Bool = true,
) -> ParsedUrl raise TransferError {
  if self.user_info is Some(info) && (info.is_empty() || info.has_prefix(":")) {
    raise invalid_url("URL username is empty")
  }
  if !self.host_normalized {
    for character in self.endpoint {
      guard !unsafe_request_character(character) else {
        raise invalid_url(
          "URL host contains an unescaped space or control character",
        )
      }
    }
  }
  let host = self.transfer_host(utf8_hosts)
  let endpoint = host + self.endpoint[self.host.length():].to_owned()
  let authority = match self.user_info {
    Some(user_info) => user_info + "@" + endpoint
    None => endpoint
  }
  {
    scheme: self.scheme,
    authority,
    endpoint,
    user_info: self.user_info,
    host,
    host_normalized: true,
    ip_literal: self.ip_literal,
    port: self.port,
    path: request_component(self.path),
    query: match self.query {
      Some(query) => Some(request_component(query))
      None => None
    },
  }
}
