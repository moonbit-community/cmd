///|
struct StoredCookie {
  name : String
  value : String
  domain : String
  host_only : Bool
  path : String
  secure : Bool
  http_only : Bool
  expires : Int64?
  live : Bool
}

///|
fn StoredCookie::expired(self : StoredCookie, now : Int64) -> Bool {
  match self.expires {
    None => false
    Some(expiry) => expiry <= now
  }
}

///|
/// A cookie store shared by transfers. Persistence uses the Netscape jar format.
pub struct CookieJar {
  priv mut entries : Array[StoredCookie]
}

///|
pub fn CookieJar::new() -> CookieJar {
  { entries: [], }
}

///|
fn cookie_ascii_lower(value : String) -> String {
  let output = StringBuilder()
  for character in value {
    output.write_char(
      if character >= 'A' && character <= 'Z' {
        (character.to_int() + 32).to_char().unwrap()
      } else {
        character
      },
    )
  }
  output.to_string()
}

///|
fn cookie_stored_domain(value : String) -> String {
  let domain = if value.has_prefix(".") { value[1:].to_owned() } else { value }
  domain
}

///|
fn ParsedUrl::cookie_host(self : ParsedUrl) -> String {
  let host = cookie_text(@utf8.encode(self.host))
  if self.ip_literal {
    cookie_ascii_lower(host[1:host.length() - 1].to_owned())
  } else {
    host
  }
}

///|
fn cookie_secure_context(url : ParsedUrl) -> Bool {
  url.scheme == "https" ||
  ["localhost", "127.0.0.1", "::1"].contains(
    cookie_ascii_lower(url.cookie_host()),
  )
}

///|
fn curl_cookie_path(value : String) -> String {
  let value = if value.has_prefix("\"") {
    let value = value[1:]
    if value.has_suffix("\"") {
      value[:value.length() - 1].to_owned()
    } else {
      value.to_owned()
    }
  } else {
    value
  }
  if !value.has_prefix("/") {
    "/"
  } else if value.length() > 1 && value.has_suffix("/") {
    value[:value.length() - 1].to_owned()
  } else {
    value
  }
}

///|
fn cookie_prefix_allowed(cookie : StoredCookie) -> Bool {
  if cookie.name.has_prefix("__Secure-") {
    return cookie.secure
  }
  if cookie.name.has_prefix("__Host-") {
    return cookie.secure && cookie.host_only && cookie.path == "/"
  }
  true
}

///|
fn cookie_same_key(left : StoredCookie, right : StoredCookie) -> Bool {
  left.name == right.name &&
  cookie_ascii_lower(left.domain) == cookie_ascii_lower(right.domain) &&
  left.path == right.path &&
  left.host_only == right.host_only
}

///|
fn CookieJar::blocks_insecure_cookie(
  self : CookieJar,
  cookie : StoredCookie,
  now : Int64,
) -> Bool {
  self.entries.any(old => {
    if !old.secure ||
      old.name != cookie.name ||
      (old.expires is Some(expiry) && expiry <= now) {
      return false
    }
    let old_domain = cookie_ascii_lower(old.domain)
    let new_domain = cookie_ascii_lower(cookie.domain)
    let overlapping = old_domain == new_domain ||
      old_domain.has_suffix("." + new_domain) ||
      new_domain.has_suffix("." + old_domain)
    let prefix = match old.path[1:].find("/") {
      Some(index) => old.path[:index + 1]
      None => old.path[:]
    }
    // The pinned curl protects the old path's first component prefix.
    overlapping && cookie.path.has_prefix(prefix)
  })
}

///|
fn cookie_domain_matches(host : String, domain : String) -> Bool {
  let host = cookie_ascii_lower(host)
  let domain = cookie_ascii_lower(domain)
  if host == domain {
    return true
  }
  // An IP address never suffix-matches a Domain attribute.
  let numeric = host
    .iter()
    .all(char => (char >= '0' && char <= '9') || char == '.')
  !numeric && !host.contains(":") && host.has_suffix("." + domain)
}

///|
fn cookie_path_matches(request : String, path : String) -> Bool {
  request == path ||
  (
    request.has_prefix(path) &&
    (path.has_suffix("/") || request[path.length():].has_prefix("/"))
  )
}

///|
fn default_cookie_path(path : String) -> String {
  match path.rev_find("/") {
    Some(index) if index > 0 => path[:index].to_owned()
    _ => "/"
  }
}

///|
fn cookie_date(value : String) -> Int64? {
  // RFC 6265 date tokens accept RFC 1123, RFC 850 and asctime spellings.
  let tokens : Array[String] = []
  let token = StringBuilder()
  for char in value {
    let code = char.to_int()
    let delimiter = code == 9 ||
      (code >= 32 && code <= 47) ||
      (code >= 59 && code <= 64) ||
      (code >= 91 && code <= 96) ||
      (code >= 123 && code <= 126)
    if delimiter {
      if !token.is_empty() {
        tokens.push(token.to_string())
        token.reset()
      }
    } else {
      token.write_char(char)
    }
  }
  if !token.is_empty() {
    tokens.push(token.to_string())
  }
  let mut day : Int32? = None
  let mut month : Int32? = None
  let mut year : Int32? = None
  let mut clock : (Int32, Int32, Int32)? = None
  let months = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov",
    "dec",
  ]
  for token in tokens {
    if clock is None && token.contains(":") {
      let parts = token.split(":").map(part => part.to_owned()).collect()
      if parts.length() == 3 {
        let parsed = Some(
          (
            @string.parse_int(parts[0]),
            @string.parse_int(parts[1]),
            @string.parse_int(parts[2]),
          ),
        ) catch {
          _ => None
        }
        if parsed is Some(_) {
          clock = parsed
          continue
        }
      }
    }
    if day is None && token.length() <= 2 {
      let parsed = Some(@string.parse_int(token)) catch { _ => None }
      if parsed is Some(_) {
        day = parsed
        continue
      }
    }
    if month is None && token.length() >= 3 {
      let name = token[:3].to_owned().to_lower()
      let mut found = false
      for index, candidate in months {
        if name == candidate {
          month = Some(index + 1)
          found = true
          break
        }
      }
      if found {
        continue
      }
    }
    if year is None && token.length() >= 2 && token.length() <= 4 {
      year = Some(@string.parse_int(token)) catch { _ => None }
    }
  }
  guard day is Some(day) &&
    month is Some(month) &&
    year is Some(year) &&
    clock is Some((hour, minute, second)) else {
    return None
  }
  let year = if year >= 70 && year <= 99 {
    year + 1900
  } else if year <= 69 {
    year + 2000
  } else {
    year
  }
  if year < 1601 {
    return None
  }
  Some(
    @time.PlainDateTime::of(year, month, day, hour~, minute~, second~).to_unix_second(),
  ) catch {
    _ => None
  }
}

///|
fn CookieJar::replace(
  self : CookieJar,
  cookie : StoredCookie,
  discard~ : Bool = false,
) -> Unit {
  let mut index : Int32? = None
  for position, old in self.entries {
    if cookie_same_key(old, cookie) {
      // File reloads must not overwrite a cookie received from a response.
      if !cookie.live && old.live {
        return
      }
      index = Some(position)
      break
    }
  }
  if discard {
    self.entries = self.entries.filter(old => !cookie_same_key(old, cookie))
  } else {
    match index {
      Some(index) => self.entries[index] = cookie
      None => self.entries.push(cookie)
    }
  }
}

///|
fn CookieJar::receive(
  self : CookieJar,
  url : ParsedUrl,
  cookies : Array[Cookie],
  now : Int64,
) -> Unit {
  let host = url.cookie_host()
  let secure_context = cookie_secure_context(url)
  for cookie in cookies {
    let discard = false
    if cookie.name == "" ||
      cookie.name.contains("\t") ||
      cookie.value.contains("\t") {
      continue
    }
    if cookie.secure && !secure_context {
      continue
    }
    let (domain, host_only) = match cookie.domain {
      Some(domain) if domain != "" => {
        let domain = cookie_stored_domain(domain)
        if domain == "" {
          continue
        }
        if !cookie_domain_matches(host, domain) {
          continue
        }
        let host_only = host.contains(":") ||
          host
          .iter()
          .all(character => {
            (character >= '0' && character <= '9') || character == '.'
          })
        (domain, host_only)
      }
      _ => (host, true)
    }
    if !curl_suffix_admission(Some(host), domain) {
      continue
    }
    let host_only = host_only ||
      (
        cookie_ascii_lower(host) == cookie_ascii_lower(domain) &&
        !@netops.cookie_ip_literal(domain) &&
        @netops.cookie_public_suffix(cookie_utf8(curl_suffix_name(domain)))
      )
    let path = match cookie.path {
      Some(path) if path != "" => curl_cookie_path(path)
      _ => default_cookie_path(cookie_text(@utf8.encode(url.path)))
    }
    let expires = match cookie.max_age {
      Some(age) if age <= 0L => Some(0L)
      Some(age) => {
        let expiry = now + age.min(9223372036854775807L - now)
        let limit = 34560000L
        Some(
          if now < 9223372036854775807L - limit - 30L && expiry > now + limit {
            (now + limit + 30L) / 60L * 60L
          } else {
            expiry
          },
        )
      }
      None =>
        match cookie.expires_raw {
          Some(value) => cookie_date(value)
          None => None
        }
    }
    let stored : StoredCookie = {
      name: cookie.name,
      value: cookie.value,
      domain,
      host_only,
      path,
      secure: cookie.secure,
      http_only: cookie.http_only,
      expires,
      live: true,
    }
    if !cookie_prefix_allowed(stored) ||
      (
        !secure_context &&
        !stored.secure &&
        self.blocks_insecure_cookie(stored, now)
      ) {
      continue
    }
    self.entries = self.entries.filter(cookie => !cookie.expired(now))
    // Domain and expiry rejection requests are applied after Path validation.
    self.replace(stored, discard~)
  }
}

///|
fn cookie_sorts_before(left : StoredCookie, right : StoredCookie) -> Bool {
  let left_path = left.path.length()
  let right_path = right.path.length()
  let left_domain = left.domain.length()
  let right_domain = right.domain.length()
  if left_path != right_path {
    return left_path > right_path
  }
  if left_domain != right_domain {
    return left_domain > right_domain
  }
  let left_name = left.name.length()
  let right_name = right.name.length()
  if left_name != right_name {
    return left_name > right_name
  }
  // The insertion walk visits newer entries last. Replacements retain their
  // original slot, so moving an equal key first preserves curl's creation order.
  true
}

///|
fn CookieJar::header_octets(
  self : CookieJar,
  url : ParsedUrl,
  now : Int64,
) -> String? {
  self.entries = self.entries.filter(cookie => {
    match cookie.expires {
      Some(expiry) => expiry > now
      None => true
    }
  })
  let host = url.cookie_host()
  let secure_context = cookie_secure_context(url)
  let request_path = cookie_text(@utf8.encode(url.path))
  let selected = self.entries.filter(cookie => {
    !cookie.expired(now) &&
    (if cookie.host_only {
      cookie_ascii_lower(host) == cookie_ascii_lower(cookie.domain)
    } else {
      cookie_domain_matches(host, cookie.domain)
    }) &&
    cookie_path_matches(request_path, cookie.path) &&
    (!cookie.secure || secure_context)
  })
  // Retain the pinned domain/path/name ordering without changing stored order.
  for index = 1; index < selected.length(); index = index + 1 {
    let cookie = selected[index]
    let mut position = index
    while position > 0 && cookie_sorts_before(cookie, selected[position - 1]) {
      selected[position] = selected[position - 1]
      position -= 1
    }
    selected[position] = cookie
  }
  if selected.is_empty() {
    None
  } else {
    Some(selected.map(cookie => cookie.name + "=" + cookie.value).join("; "))
  }
}

///|
pub fn CookieJar::load_bytes(self : CookieJar, bytes : Bytes) -> Bool {
  self.load_octets_at(cookie_text(bytes), @fsops.current_timestamp().seconds)
}

///|
fn CookieJar::load_octets_at(
  self : CookieJar,
  text : String,
  now : Int64,
) -> Bool {
  let (lines, complete) = cookie_file_lines(text)
  for line in lines {
    let end = line.find("\r").unwrap_or(line.length())
    let line = line[:end].to_owned()
    let http_only = line.has_prefix("#HttpOnly_")
    let line = if http_only { line[10:].to_owned() } else { line }
    if line == "" || line.has_prefix("#") {
      continue
    }
    let fields = line.split("\t").map(field => field.to_owned()).collect()
    if fields.length() == 6 {
      fields.push("")
    }
    if fields.length() != 7 {
      continue
    }
    // Curl interprets these spellings as an omitted path and shifts columns.
    // A seven-column row then has excess fields; its normal path is not '/'.
    if "TRUE".has_prefix(fields[2]) || "FALSE".has_prefix(fields[2]) {
      continue
    }
    let expires = {
      let value = @string.parse_int64(fields[4]) catch { _ => continue }
      if value == 0L {
        None
      } else {
        Some(value)
      }
    }
    let domain = cookie_stored_domain(fields[0])
    if domain == "" || fields[5] == "" {
      continue
    }
    if cookie_control(fields[5]) || cookie_control(fields[6]) {
      continue
    }
    if !curl_suffix_admission(None, domain) {
      continue
    }
    let cookie : StoredCookie = {
      name: fields[5],
      value: fields[6],
      domain,
      host_only: fields[1].to_upper() != "TRUE",
      path: curl_cookie_path(fields[2]),
      secure: fields[3].to_upper() == "TRUE",
      http_only,
      expires,
      live: false,
    }
    if !cookie_prefix_allowed(cookie) {
      continue
    }
    self.replace(cookie)
  }
  self.entries = self.entries.filter(cookie => !cookie.expired(now))
  complete
}

///|
fn CookieJar::netscape_octets(
  self : CookieJar,
  include_session~ : Bool = true,
  now~ : Int64 = @fsops.current_timestamp().seconds,
) -> String {
  self.entries = self.entries.filter(cookie => !cookie.expired(now))
  let out = StringBuilder()
  out.write_string(
    "# Netscape HTTP Cookie File\n# https://curl.se/docs/http-cookies.html\n# This file was generated by libcurl! Edit at your own risk.\n\n",
  )
  let mut curl_index = self.entries.length() - 1
  for _ in self.entries {
    // Curl saves newest creation first; replacement keeps its array position.
    // Selecting its entries in reverse leaves other s' order intact.
    let cookie = {
      let selected = self.entries[curl_index]
      curl_index -= 1
      selected
    }
    if cookie.expired(now) {
      continue
    }
    if !include_session && cookie.expires is None {
      continue
    }
    if cookie.http_only {
      out.write_string("#HttpOnly_")
    }
    if !cookie.host_only && !cookie.domain.has_prefix(".") {
      out.write_string(".")
    }
    out.write_string(cookie.domain)
    out.write_string(if cookie.host_only { "\tFALSE\t" } else { "\tTRUE\t" })
    out.write_string(cookie.path)
    out.write_string(if cookie.secure { "\tTRUE\t" } else { "\tFALSE\t" })
    let expiry = cookie.expires.unwrap_or(0L)
    out.write_string(expiry.to_string())
    out.write_string("\t" + cookie.name + "\t" + cookie.value + "\n")
  }
  out.to_string()
}

///|
pub async fn CookieJar::load(self : CookieJar, path : String) -> Bool {
  self.load_bytes(@fs.read_file(path).binary())
}

///|
pub async fn CookieJar::save(
  self : CookieJar,
  path : String,
  include_session~ : Bool = true,
) -> Unit {
  let text = cookie_bytes(self.netscape_octets(include_session~))
  if path == "-" {
    @stdio.stdout.write(text)
  } else {
    @fs.write_file(path, text, permission=0o666)
  }
}
