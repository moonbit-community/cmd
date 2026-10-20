///|
fn unsafe_request_character(character : Char) -> Bool {
  character <= ' ' || character == '\u007f'
}

///|
fn request_component(
  value : String,
  profile : TransferProfile,
  redirect~ : Bool,
  query~ : Bool = false,
) -> String raise TransferError {
  let result = StringBuilder()
  for character in value {
    if unsafe_request_character(character) {
      guard profile == WgetProfile || (profile == CurlProfile && redirect) else {
        raise invalid_url(
          if profile == CurlProfile {
            "URL rejected: Malformed input to a URL function"
          } else {
            "URL request target contains an unescaped space or control character"
          },
        )
      }
      if profile == CurlProfile && redirect && query && character == ' ' {
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
fn ParsedUrl::for_transfer(
  self : ParsedUrl,
  profile : TransferProfile,
  redirect~ : Bool = false,
) -> ParsedUrl raise TransferError {
  for character in self.endpoint {
    guard !unsafe_request_character(character) else {
      raise invalid_url(
        "URL host contains an unescaped space or control character",
      )
    }
  }
  {
    scheme: self.scheme,
    authority: self.authority,
    endpoint: self.endpoint,
    user_info: self.user_info,
    host: self.host,
    port: self.port,
    path: request_component(self.path, profile, redirect~),
    query: match self.query {
      Some(query) =>
        Some(request_component(query, profile, redirect~, query=true))
      None => None
    },
  }
}
