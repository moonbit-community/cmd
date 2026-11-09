///|
struct StoredCookie {
  name : String
  value : String
  domain : String
  host_only : Bool
  port : Int32?
  path : String
  secure : Bool
  http_only : Bool
  expires : Int64?
  profile : TransferProfile
  live : Bool
}

///|
fn StoredCookie::expired(self : StoredCookie, now : Int64) -> Bool {
  match self.expires {
    None => false
    Some(expiry) =>
      if self.profile == WgetProfile {
        expiry != 0L && expiry < now
      } else {
        expiry <= now
      }
  }
}

///|
/// A cookie store shared by transfers. Persistence uses the Netscape jar format.
pub struct CookieJar {
  mut entries : Array[StoredCookie]
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
fn cookie_stored_domain(value : String, profile : TransferProfile) -> String {
  let domain = if profile == StrictProfile {
    value.trim_start(chars=".").to_owned()
  } else if value.has_prefix(".") {
    value[1:].to_owned()
  } else {
    value
  }
  if profile != StrictProfile {
    domain
  } else {
    domain.to_lower()
  }
}

///|
fn ParsedUrl::cookie_host(
  self : ParsedUrl,
  profile : TransferProfile,
) -> String {
  let host = if profile == CurlProfile {
    self.host
  } else {
    self.host.to_lower()
  }
  if profile == CurlProfile && self.ip_literal {
    cookie_ascii_lower(host[1:host.length() - 1].to_owned())
  } else {
    host
  }
}

///|
fn cookie_secure_context(url : ParsedUrl, profile : TransferProfile) -> Bool {
  url.scheme == "https" ||
  (
    profile == CurlProfile &&
    ["localhost", "127.0.0.1", "::1"].contains(
      cookie_ascii_lower(url.cookie_host(profile)),
    )
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
fn cookie_same_key(
  left : StoredCookie,
  right : StoredCookie,
  profile : TransferProfile,
) -> Bool {
  left.name == right.name &&
  (if profile != StrictProfile {
    cookie_ascii_lower(left.domain) == cookie_ascii_lower(right.domain)
  } else {
    left.domain == right.domain
  }) &&
  left.path == right.path &&
  (profile != WgetProfile || left.port == right.port) &&
  (profile != CurlProfile || left.host_only == right.host_only)
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
    // The pinned curl profile protects the old path's first component prefix.
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
  now : Int64,
  profile~ : TransferProfile = StrictProfile,
  discard~ : Bool = false,
) -> Unit {
  // Wget's case-insensitive domain table retains its first key spelling until
  // the last cookie in that domain chain is explicitly removed.
  let cookie = if profile == WgetProfile {
    let mut spelling = cookie.domain
    for old in self.entries {
      if cookie_ascii_lower(old.domain) == cookie_ascii_lower(cookie.domain) {
        spelling = old.domain
        break
      }
    }
    { ..cookie, domain: spelling, }
  } else {
    cookie
  }
  let mut index : Int32? = None
  for position, old in self.entries {
    if cookie_same_key(old, cookie, profile) {
      // File reloads must not overwrite a cookie received from a response.
      if profile == CurlProfile && !cookie.live && old.live {
        return
      }
      index = Some(position)
      break
    }
  }
  if discard ||
    (
      profile == StrictProfile &&
      cookie.expires is Some(expiry) &&
      expiry <= now
    ) {
    self.entries = self.entries.filter(old => {
      !cookie_same_key(old, cookie, profile)
    })
  } else if profile == WgetProfile {
    self.entries = [
      cookie,
      ..self.entries.filter(old => !cookie_same_key(old, cookie, profile)),
    ]
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
  profile~ : TransferProfile = StrictProfile,
) -> Unit {
  let host = url.cookie_host(profile)
  let secure_context = cookie_secure_context(url, profile)
  for cookie in cookies {
    let mut discard = false
    if cookie.name == "" ||
      cookie.name.contains("\t") ||
      cookie.value.contains("\t") {
      continue
    }
    if profile == WgetProfile &&
      (cookie.domain == Some("") || cookie.path == Some("")) {
      continue
    }
    if profile == CurlProfile && cookie.secure && !secure_context {
      continue
    }
    let (domain, host_only) = match cookie.domain {
      Some(domain) if domain != "" => {
        let domain = cookie_stored_domain(domain, profile)
        if domain == "" {
          continue
        }
        if profile != WgetProfile && !cookie_domain_matches(host, domain) {
          continue
        }
        let host_only = profile == CurlProfile &&
          (
            host.contains(":") ||
            host
            .iter()
            .all(character => {
              (character >= '0' && character <= '9') || character == '.'
            })
          )
        (domain, host_only)
      }
      _ => (host, true)
    }
    if profile == CurlProfile && !curl_suffix_admission(Some(host), domain) {
      continue
    }
    if profile == WgetProfile && !wget_cookie_domain_allows(host, domain) {
      discard = true
    }
    let host_only = host_only ||
      (
        profile == CurlProfile &&
        cookie_ascii_lower(host) == cookie_ascii_lower(domain) &&
        !cookie_ip_literal(domain) &&
        cookie_public_suffix(curl_suffix_name(domain))
      )
    let path = if profile == CurlProfile {
      match cookie.path {
        Some(path) if path != "" => curl_cookie_path(path)
        _ => default_cookie_path(url.path)
      }
    } else if profile == WgetProfile {
      match cookie.path {
        Some(path) => {
          if !url.path.has_prefix(path) {
            continue
          }
          path
        }
        None =>
          match url.path.rev_find("/") {
            Some(index) => url.path[:index + 1].to_owned()
            None => "/"
          }
      }
    } else {
      match cookie.path {
        Some(path) if path.has_prefix("/") => path
        _ => default_cookie_path(url.path)
      }
    }
    let mut expires = match cookie.max_age {
      Some(age) if age <= 0L => Some(0L)
      Some(age) => {
        let expiry = now + age.min(9223372036854775807L - now)
        let limit = 34560000L
        Some(
          if profile == CurlProfile &&
            now < 9223372036854775807L - limit - 30L &&
            expiry > now + limit {
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
    if profile == WgetProfile {
      // Preserve the original floating value through parsing: a nonzero age
      // truncating to zero is a permanent cookie valid during this second.
      let operations = if cookie.wget_expiry.is_empty() {
        match cookie.max_age {
          Some(age) => [Age(age.to_double())]
          None =>
            match expires {
              Some(date) => [Date(date)]
              None => []
            }
        }
      } else {
        cookie.wget_expiry
      }
      expires = None
      for operation in operations {
        match operation {
          Age(age) => {
            expires = Some(now + wget_cookie_time(age))
            discard = discard || age == 0.0
          }
          Date(date) => {
            expires = Some(date)
            discard = discard || date < now
          }
        }
      }
    }
    let stored : StoredCookie = {
      name: cookie.name,
      value: cookie.value,
      domain,
      host_only,
      port: if profile == WgetProfile && host_only {
        match url.port {
          Some(port) if port != 80 && port != 443 => Some(port)
          _ => None
        }
      } else {
        None
      },
      path,
      secure: cookie.secure,
      http_only: profile != WgetProfile && cookie.http_only,
      expires,
      profile,
      live: true,
    }
    if profile == CurlProfile &&
      (
        !cookie_prefix_allowed(stored) ||
        (
          !secure_context &&
          !stored.secure &&
          self.blocks_insecure_cookie(stored, now)
        )
      ) {
      continue
    }
    if profile == CurlProfile {
      self.entries = self.entries.filter(cookie => !cookie.expired(now))
    }
    // Domain and expiry rejection requests are applied after Path validation.
    self.replace(stored, now, profile~, discard~)
  }
}

///|
fn cookie_sorts_before(
  left : StoredCookie,
  right : StoredCookie,
  profile : TransferProfile,
) -> Bool {
  if profile == StrictProfile {
    return left.path.length() > right.path.length()
  }
  let left_path = @utf8.encode(left.path).length()
  let right_path = @utf8.encode(right.path).length()
  let left_domain = @utf8.encode(left.domain).length()
  let right_domain = @utf8.encode(right.domain).length()
  if profile == WgetProfile {
    if left_domain != right_domain {
      return left_domain > right_domain
    }
    if left_path != right_path {
      return left_path > right_path
    }
    let names = @utf8.encode(left.name).lexical_compare(
      @utf8.encode(right.name),
    )
    if names != 0 {
      return names < 0
    }
    return @utf8.encode(left.value).lexical_compare(@utf8.encode(right.value)) <
      0
  }
  if left_path != right_path {
    return left_path > right_path
  }
  if left_domain != right_domain {
    return left_domain > right_domain
  }
  let left_name = @utf8.encode(left.name).length()
  let right_name = @utf8.encode(right.name).length()
  if left_name != right_name {
    return left_name > right_name
  }
  // The insertion walk visits newer entries last. Replacements retain their
  // original slot, so moving an equal key first preserves curl's creation order.
  true
}

///|
fn CookieJar::header_for(
  self : CookieJar,
  url : ParsedUrl,
  now : Int64,
  profile~ : TransferProfile = StrictProfile,
) -> String? {
  if profile != WgetProfile {
    self.entries = self.entries.filter(cookie => {
      match cookie.expires {
        Some(expiry) => expiry > now
        None => true
      }
    })
  }
  let host = url.cookie_host(profile)
  let secure_context = cookie_secure_context(url, profile)
  if profile == WgetProfile && !wget_cookie_host_allowed(host) {
    return None
  }
  let mut selected = self.entries.filter(cookie => {
    !cookie.expired(now) &&
    (
      cookie.port is None ||
      cookie.port ==
      Some(url.port.unwrap_or(if url.scheme == "https" { 443 } else { 80 }))
    ) &&
    (if cookie.host_only {
      if profile != StrictProfile {
        cookie_ascii_lower(host) == cookie_ascii_lower(cookie.domain)
      } else {
        host == cookie.domain
      }
    } else {
      cookie_domain_matches(host, cookie.domain) &&
      (
        profile != WgetProfile ||
        cookie_ascii_lower(host) == cookie_ascii_lower(cookie.domain) ||
        cookie.domain.contains(".")
      )
    }) &&
    (if profile == WgetProfile {
      url.path.has_prefix(cookie.path)
    } else {
      cookie_path_matches(url.path, cookie.path)
    }) &&
    (!cookie.secure || secure_context)
  })
  if profile == WgetProfile {
    // The pinned Wget walks more-specific domain chains first, newest cookie
    // first within each chain. Its duplicate pass retains the last equal pair
    // before sorting by domain/path quality. Persistence retains chain order.
    for index = 1; index < selected.length(); index = index + 1 {
      let cookie = selected[index]
      let mut position = index
      while position > 0 &&
            @utf8.encode(cookie.domain).length() >
            @utf8.encode(selected[position - 1].domain).length() {
        selected[position] = selected[position - 1]
        position -= 1
      }
      selected[position] = cookie
    }
    let unique : Array[StoredCookie] = []
    for index, cookie in selected {
      let mut duplicate = false
      for later in selected[index + 1:] {
        if cookie.name == later.name && cookie.value == later.value {
          duplicate = true
          break
        }
      }
      if !duplicate {
        unique.push(cookie)
      }
    }
    selected = unique
  }
  // Strict retains creation order among equal-length paths. The command profiles
  // preserve their pinned domain/path/name ordering without changing stored order.
  for index = 1; index < selected.length(); index = index + 1 {
    let cookie = selected[index]
    let mut position = index
    while position > 0 &&
          cookie_sorts_before(cookie, selected[position - 1], profile) {
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
pub fn CookieJar::load_netscape(
  self : CookieJar,
  text : String,
  profile~ : TransferProfile = StrictProfile,
) -> Unit {
  self.load_netscape_at(text, @fsops.current_timestamp().seconds, profile)
}

///|
fn CookieJar::load_netscape_at(
  self : CookieJar,
  text : String,
  now : Int64,
  profile : TransferProfile,
) -> Unit {
  for line in text.split("\n") {
    let line = if profile == WgetProfile {
      let line = line.trim_start(chars=" \t\r\n\u{000b}\u{000c}")
      if line.has_suffix("\r") {
        line[:line.length() - 1].to_owned()
      } else {
        line.to_owned()
      }
    } else {
      line.trim_end(chars="\r").to_owned()
    }
    let http_only = profile != WgetProfile && line.has_prefix("#HttpOnly_")
    let line = if http_only { line[10:].to_owned() } else { line }
    if line == "" || line.has_prefix("#") {
      continue
    }
    let mut fields = line.split("\t").map(field => field.to_owned()).collect()
    if profile == WgetProfile && fields.length() > 7 {
      let value = fields[6:].to_owned().join("\t")
      fields = [..fields[:6], value]
    }
    if fields.length() != 7 {
      continue
    }
    if profile == WgetProfile && fields[:6].iter().any(field => field == "") {
      continue
    }
    // Curl interprets these spellings as an omitted path and shifts columns.
    // A seven-column row then has excess fields; its normal path is not '/'.
    if profile == CurlProfile &&
      ("TRUE".has_prefix(fields[2]) || "FALSE".has_prefix(fields[2])) {
      continue
    }
    let expires = if profile == WgetProfile {
      guard wget_cookie_number(fields[4]) is Some(value) else { continue }
      if value == 0.0 {
        None
      } else {
        if value < now.to_double() {
          continue
        }
        Some(wget_cookie_time(value))
      }
    } else {
      let value = @string.parse_int64(fields[4]) catch { _ => continue }
      if value == 0L {
        None
      } else {
        Some(value)
      }
    }
    let (domain, port) = if profile == WgetProfile {
      wget_cookie_domain_port(fields[0])
    } else {
      (fields[0], None)
    }
    let domain = cookie_stored_domain(domain, profile)
    if domain == "" ||
      fields[5] == "" ||
      (profile == StrictProfile && !fields[2].has_prefix("/")) {
      continue
    }
    if profile == CurlProfile && !curl_suffix_admission(None, domain) {
      continue
    }
    let cookie : StoredCookie = {
      name: fields[5],
      value: fields[6],
      domain,
      host_only: (if profile == WgetProfile {
        fields[1]
      } else {
        fields[1].to_upper()
      }) !=
      "TRUE",
      port,
      path: if profile == CurlProfile {
        curl_cookie_path(fields[2])
      } else {
        fields[2]
      },
      secure: (if profile == WgetProfile {
        fields[3]
      } else {
        fields[3].to_upper()
      }) ==
      "TRUE",
      http_only,
      expires,
      profile,
      live: false,
    }
    if profile == CurlProfile && !cookie_prefix_allowed(cookie) {
      continue
    }
    self.replace(cookie, now, profile~)
  }
  if profile == CurlProfile {
    self.entries = self.entries.filter(cookie => !cookie.expired(now))
  }
}

///|
fn CookieJar::netscape(
  self : CookieJar,
  include_session~ : Bool = true,
  now~ : Int64 = @fsops.current_timestamp().seconds,
  profile~ : TransferProfile = StrictProfile,
) -> String {
  self.entries = self.entries.filter(cookie => {
    cookie.profile != CurlProfile || !cookie.expired(now)
  })
  let out = StringBuilder()
  out.write_string(
    if profile == CurlProfile {
      "# Netscape HTTP Cookie File\n# https://curl.se/docs/http-cookies.html\n# This file was generated by libcurl! Edit at your own risk.\n\n"
    } else {
      "# Netscape HTTP Cookie File\n# Generated by cli/core\n\n"
    },
  )
  let mut curl_index = self.entries.length() - 1
  for cookie in self.entries {
    // Curl saves newest creation first; replacement keeps its array position.
    // Selecting its entries in reverse leaves other profiles' order intact.
    let cookie = if cookie.profile == CurlProfile {
      while self.entries[curl_index].profile != CurlProfile {
        curl_index -= 1
      }
      let selected = self.entries[curl_index]
      curl_index -= 1
      selected
    } else {
      cookie
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
    if !cookie.host_only &&
      (cookie.profile != CurlProfile || !cookie.domain.has_prefix(".")) {
      out.write_string(".")
    }
    out.write_string(cookie.domain)
    if cookie.port is Some(port) {
      out.write_string(":" + port.to_string())
    }
    out.write_string(if cookie.host_only { "\tFALSE\t" } else { "\tTRUE\t" })
    out.write_string(cookie.path)
    out.write_string(if cookie.secure { "\tTRUE\t" } else { "\tFALSE\t" })
    let expiry = cookie.expires.unwrap_or(0L)
    out.write_string(
      if cookie.profile == WgetProfile {
        wget_cookie_saved_time(expiry)
      } else {
        expiry.to_string()
      },
    )
    out.write_string("\t" + cookie.name + "\t" + cookie.value + "\n")
  }
  out.to_string()
}

///|
pub async fn CookieJar::load(
  self : CookieJar,
  path : String,
  profile~ : TransferProfile = StrictProfile,
) -> Unit {
  self.load_netscape(@fs.read_file(path).text(), profile~)
}

///|
pub async fn CookieJar::save(
  self : CookieJar,
  path : String,
  include_session~ : Bool = true,
  profile~ : TransferProfile = StrictProfile,
) -> Unit {
  let text = self.netscape(include_session~, profile~)
  if path == "-" {
    @stdio.stdout.write(text)
  } else {
    @fs.write_file(path, text, permission=0o666)
  }
}
