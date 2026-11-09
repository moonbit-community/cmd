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
      guard byte >= b' ' && byte != b'\x7f' else {
        raise invalid_url("URL host contains an escaped control character")
      }
      output.write_byte(byte)
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
  {
    let forbidden = " /:#?!@{}[]\\$'\"^`*<>=;,+&()%|"
    guard decoded != "." &&
      !decoded.has_suffix("..") &&
      !decoded
      .iter()
      .any(character => forbidden.contains(character.to_string())) else {
      raise invalid_url("URL rejected: Bad hostname")
    }
  }
  if decoded.iter().all(character => character.to_int() < 128) {
    return decoded
  }
  if !utf8_hosts {
    raise invalid_url("URL rejected: International host requires UTF-8 input")
  }
  @netops.idna_host(decoded) catch {
    _ => raise invalid_url("URL rejected: Invalid international host name")
  }
}

///|
fn request_component(
  value : String,
  redirect~ : Bool,
  query~ : Bool = false,
) -> String raise TransferError {
  let result = StringBuilder()
  for character in value {
    if unsafe_request_character(character) {
      guard redirect else {
        raise invalid_url("URL rejected: Malformed input to a URL function")
      }
      if redirect && query && character == ' ' {
        result.write_char('+')
        continue
      }
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
  self.endpoint
}

///|
fn ParsedUrl::for_transfer(
  self : ParsedUrl,
  redirect~ : Bool = false,
  utf8_hosts~ : Bool = true,
) -> ParsedUrl raise TransferError {
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
  if host.is_empty() {
    raise invalid_url("URL host is empty after IDNA processing")
  }
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
    path: request_component(self.path, redirect~),
    query: match self.query {
      Some(query) => Some(request_component(query, redirect~, query=true))
      None => None
    },
  }
}
