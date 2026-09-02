///|
priv struct ParsedUrl {
  scheme : String
  authority : String
  endpoint : String
  user_info : String?
  host : String
  port : Int?
  path : String
  query : String?
}

///|
fn invalid_url(message : String) -> TransferError {
  TransferError(kind=InvalidUrl, message~, status=None)
}

///|
fn is_ascii_alpha(char : Char) -> Bool {
  (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
}

///|
fn is_scheme_char(char : Char) -> Bool {
  is_ascii_alpha(char) ||
  (char >= '0' && char <= '9') ||
  char == '+' ||
  char == '-' ||
  char == '.'
}

///|
fn valid_scheme(value : String) -> Bool {
  guard value.get_char(0) is Some(first) && is_ascii_alpha(first) else {
    return false
  }
  for char in value {
    if !is_scheme_char(char) {
      return false
    }
  }
  true
}

///|
fn split_fragment(value : String) -> String {
  match value.find("#") {
    Some(index) => value[:index].to_owned()
    None => value
  }
}

///|
fn split_query(value : String) -> (String, String?) {
  match value.find("?") {
    Some(index) =>
      (value[:index].to_owned(), Some(value[index + 1:].to_owned()))
    None => (value, None)
  }
}

///|
fn first_authority_separator(value : String) -> Int? {
  let slash = value.find("/")
  let query = value.find("?")
  match (slash, query) {
    (Some(left), Some(right)) => Some(left.min(right))
    (Some(index), None) | (None, Some(index)) => Some(index)
    (None, None) => None
  }
}

///|
fn parse_port(value : String) -> Int raise TransferError {
  if value == "" {
    raise invalid_url("empty URL port")
  }
  let port = @string.parse_int(value) catch {
    _ => raise invalid_url("invalid URL port '\{value}'")
  }
  if port <= 0 || port > 65535 {
    raise invalid_url("URL port is outside 1..65535: '\{value}'")
  }
  port
}

///|
fn parse_host_port(value : String) -> (String, Int?) raise TransferError {
  if value == "" {
    raise invalid_url("URL host is empty")
  }
  if value.has_prefix("[") {
    guard value.find("]") is Some(close) else {
      raise invalid_url("unterminated IPv6 URL host")
    }
    let host = value[:close + 1].to_owned()
    let suffix = value[close + 1:].to_owned()
    if suffix == "" {
      return (host, None)
    }
    if !suffix.has_prefix(":") {
      raise invalid_url("invalid text after IPv6 URL host")
    }
    return (host, Some(parse_port(suffix[1:].to_owned())))
  }
  match value.rev_split_once(":") {
    Some((host, port)) if !host.contains(":") => {
      if host.is_empty() {
        raise invalid_url("URL host is empty")
      }
      (host.to_owned(), Some(parse_port(port.to_owned())))
    }
    _ => (value, None)
  }
}

///|
fn parse_absolute_url(value : String) -> ParsedUrl raise TransferError {
  let value = split_fragment(value)
  guard value.find(":") is Some(colon) else {
    raise invalid_url("URL is missing a scheme")
  }
  let scheme = value[:colon].to_owned().to_lower()
  if !valid_scheme(scheme) {
    raise invalid_url("invalid URL scheme")
  }
  if scheme != "http" && scheme != "https" {
    raise TransferError(
      kind=UnsupportedProtocol,
      message="unsupported protocol '\{scheme}'",
      status=None,
    )
  }
  let remainder = value[colon + 1:].to_owned()
  if !remainder.has_prefix("//") {
    raise invalid_url("HTTP URL is missing // before the host")
  }
  let after_slashes = remainder[2:].to_owned()
  let (authority, path_and_query) = match
    first_authority_separator(after_slashes) {
    Some(index) =>
      (after_slashes[:index].to_owned(), after_slashes[index:].to_owned())
    None => (after_slashes, "")
  }
  if authority == "" {
    raise invalid_url("URL host is empty")
  }
  let (user_info, endpoint) = match authority.rev_split_once("@") {
    Some((user, endpoint)) => (Some(user.to_owned()), endpoint.to_owned())
    None => (None, authority)
  }
  let (host, port) = parse_host_port(endpoint)
  let (path, query) = split_query(path_and_query)
  let path = if path == "" { "/" } else { path }
  { scheme, authority, endpoint, user_info, host, port, path, query, }
}

///|
fn ParsedUrl::origin(self : ParsedUrl) -> String {
  self.scheme + "://" + self.endpoint
}

///|
fn ParsedUrl::origin_key(self : ParsedUrl) -> String {
  let port = self.port.unwrap_or(if self.scheme == "https" { 443 } else { 80 })
  self.scheme + "://" + self.host.to_lower() + ":" + port.to_string()
}

///|
fn ParsedUrl::request_target(self : ParsedUrl) -> String {
  match self.query {
    Some(query) => self.path + "?" + query
    None => self.path
  }
}

///|
fn ParsedUrl::to_url(self : ParsedUrl) -> String {
  self.scheme + "://" + self.authority + self.request_target()
}

///|
fn remove_last_path_segment(value : String) -> String {
  match value.rev_find("/") {
    Some(index) => value[:index].to_owned()
    None => ""
  }
}

///|
fn remove_dot_segments(value : String) -> String {
  let mut input = value
  let mut output = ""
  while input != "" {
    if input.has_prefix("../") {
      input = input[3:].to_owned()
    } else if input.has_prefix("./") {
      input = input[2:].to_owned()
    } else if input.has_prefix("/./") {
      input = "/" + input[3:].to_owned()
    } else if input == "/." {
      input = "/"
    } else if input.has_prefix("/../") {
      input = "/" + input[4:].to_owned()
      output = remove_last_path_segment(output)
    } else if input == "/.." {
      input = "/"
      output = remove_last_path_segment(output)
    } else if input == "." || input == ".." {
      input = ""
    } else {
      let boundary = if input.has_prefix("/") {
        match input[1:].to_owned().find("/") {
          Some(index) => index + 1
          None => input.length()
        }
      } else {
        input.find("/").unwrap_or(input.length())
      }
      output += input[:boundary].to_owned()
      input = input[boundary:].to_owned()
    }
  }
  output
}

///|
fn reference_has_scheme(value : String) -> Bool {
  guard value.find(":") is Some(colon) else { return false }
  valid_scheme(value[:colon].to_owned())
}

///|
fn resolve_location(
  base : ParsedUrl,
  location : String,
) -> ParsedUrl raise TransferError {
  let reference = split_fragment(location)
  if reference_has_scheme(reference) {
    return parse_absolute_url(reference)
  }
  if reference.has_prefix("//") {
    return parse_absolute_url(base.scheme + ":" + reference)
  }
  let (reference_path, reference_query) = split_query(reference)
  let resolved : (String, String?) = if reference_path == "" {
    let query = match reference_query {
      Some(value) => Some(value)
      None => base.query
    }
    (base.path, query)
  } else if reference_path.has_prefix("/") {
    (remove_dot_segments(reference_path), reference_query)
  } else {
    let merged = match base.path.rev_find("/") {
      Some(index) => base.path[:index + 1].to_owned() + reference_path
      None => "/" + reference_path
    }
    (remove_dot_segments(merged), reference_query)
  }
  let (path, query) = resolved
  let query_suffix = match query {
    Some(value) => "?" + value
    None => ""
  }
  parse_absolute_url(base.scheme + "://" + base.authority + path + query_suffix)
}

///|
fn hex_value(char : Char) -> Int? {
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    'a'..='f' => Some(char.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(char.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn percent_decode(value : String) -> String {
  let bytes : Array[Byte] = []
  let encoded = @utf8.encode(value)
  let mut index = 0
  while index < encoded.length() {
    if encoded[index] == b'%' && index + 2 < encoded.length() {
      let high_char = encoded[index + 1].to_char()
      let low_char = encoded[index + 2].to_char()
      guard hex_value(high_char) is Some(high) &&
        hex_value(low_char) is Some(low) else {
        bytes.push(encoded[index])
        index += 1
        continue
      }
      bytes.push(((high << 4) | low).to_byte())
      index += 3
    } else {
      bytes.push(encoded[index])
      index += 1
    }
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => value
  }
}

///|
pub fn remote_name(url : String) -> String raise TransferError {
  let parsed = parse_absolute_url(url)
  let path = parsed.path.trim_end(chars="/").to_owned()
  if path == "" {
    return "index.html"
  }
  let name = match path.rev_find("/") {
    Some(index) => path[index + 1:].to_owned()
    None => path
  }
  let decoded = percent_decode(name)
  if decoded == "" || decoded == "." || decoded == ".." {
    "index.html"
  } else {
    decoded.replace_all(old="/", new="_").replace_all(old="\\", new="_")
  }
}

///|
pub fn url_host(url : String) -> String raise TransferError {
  let host = parse_absolute_url(url).host
  if host.has_prefix("[") && host.has_suffix("]") {
    host[1:host.length() - 1].to_owned()
  } else {
    host
  }
}

///|
pub fn proxy_bypassed(url : String, no_proxy : String?) -> Bool {
  guard no_proxy is Some(list) else { return false }
  let host = try url_host(url) catch {
    _ => return false
  } noraise {
    value => value.to_lower()
  }
  for part in list.split(",") {
    let raw = part.trim().to_owned().to_lower()
    if raw == "*" {
      return true
    }
    let candidate = if raw.has_prefix("[") {
      match raw.find("]") {
        Some(index) => raw[1:index].to_owned()
        None => raw
      }
    } else {
      match raw.rev_find(":") {
        Some(index) if !raw[:index].to_owned().contains(":") =>
          raw[:index].to_owned()
        _ => raw
      }
    }
    let candidate = if candidate.has_prefix(".") {
      candidate[1:].to_owned()
    } else {
      candidate
    }
    let suffix = "." + candidate
    if host == candidate || host.has_suffix(suffix) {
      return true
    }
  }
  false
}
