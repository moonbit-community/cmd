///|
struct StoredCookie {
  name : String
  value : String
  domain : String
  host_only : Bool
  port : Int32?
  path : String
  secure : Bool
  expires : Int64?
}

///|
fn StoredCookie::expired(self : StoredCookie, now : Int64) -> Bool {
  match self.expires {
    None => false
    Some(expiry) => expiry != 0L && expiry < now
  }
}

///|
/// A cookie store shared by transfers. Persistence uses the Netscape jar format.
pub struct CookieJar {
  priv mut entries : Array[StoredCookie]
  priv domains : CookieDomains
}

///|
pub fn CookieJar::new() -> CookieJar {
  { entries: [], domains: CookieDomains::new(), }
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
  let host = cookie_text(@utf8.encode(self.host.to_lower()))
  host
}

///|
fn cookie_secure_context(url : ParsedUrl) -> Bool {
  url.scheme == "https"
}

///|
fn cookie_same_key(left : StoredCookie, right : StoredCookie) -> Bool {
  left.name == right.name &&
  cookie_ascii_lower(left.domain) == cookie_ascii_lower(right.domain) &&
  left.path == right.path &&
  left.port == right.port
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
fn CookieJar::replace(
  self : CookieJar,
  cookie : StoredCookie,
  discard~ : Bool = false,
) -> Unit {
  // Wget's case-insensitive domain table retains its first key spelling until
  // the last cookie in that domain chain is explicitly removed.
  let cookie = {
    let mut spelling = cookie.domain
    for old in self.entries {
      if cookie_ascii_lower(old.domain) == cookie_ascii_lower(cookie.domain) {
        spelling = old.domain
        break
      }
    }
    { ..cookie, domain: spelling, }
  }
  if discard {
    self.entries = self.entries.filter(old => !cookie_same_key(old, cookie))
    if !self.entries.any(old => {
        cookie_ascii_lower(old.domain) == cookie_ascii_lower(cookie.domain)
      }) {
      self.domains.remove(cookie.domain)
    }
  } else {
    self.domains.insert(cookie.domain)
    self.entries = [
      cookie,
      ..self.entries.filter(old => !cookie_same_key(old, cookie)),
    ]
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
  let request_path = cookie_text(@utf8.encode(url.path))
  for cookie in cookies {
    let mut discard = false
    if cookie.name == "" || cookie.name.contains("\t") {
      continue
    }
    if cookie.domain == Some("") || cookie.path == Some("") {
      continue
    }
    let (domain, host_only) = match cookie.domain {
      Some(domain) if domain != "" => {
        let domain = cookie_stored_domain(domain)
        if domain == "" {
          continue
        }
        (domain, false)
      }
      _ => (host, true)
    }
    if !wget_cookie_domain_allows_octets(host, domain) {
      discard = true
    }
    let path = match cookie.path {
      Some(path) => {
        if !request_path.has_prefix(path) {
          continue
        }
        path
      }
      None =>
        match request_path.rev_find("/") {
          Some(index) => request_path[:index + 1].to_owned()
          None => "/"
        }
    }
    let mut expires : Int64? = None
    // Keep the floating value: a nonzero age truncated to zero remains live now.
    for operation in cookie.wget_expiry {
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
    let stored : StoredCookie = {
      name: cookie.name,
      value: cookie.value,
      domain,
      host_only,
      port: if host_only {
        match url.port {
          Some(port) if port != 80 && port != 443 => Some(port)
          _ => None
        }
      } else {
        None
      },
      path,
      secure: cookie.secure,
      expires,
    }
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
  if left_domain != right_domain {
    return left_domain > right_domain
  }
  if left_path != right_path {
    return left_path > right_path
  }
  let names = left.name.lexical_compare(right.name)
  if names != 0 {
    return names < 0
  }
  left.value.lexical_compare(right.value) < 0
}

///|
fn CookieJar::header_octets(
  self : CookieJar,
  url : ParsedUrl,
  now : Int64,
) -> String? {
  let host = url.cookie_host()
  let request_path = cookie_text(@utf8.encode(url.path))
  if !wget_cookie_host_allowed(host) {
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
      cookie_ascii_lower(host) == cookie_ascii_lower(cookie.domain)
    } else {
      cookie_domain_matches(host, cookie.domain) &&
      (
        cookie_ascii_lower(host) == cookie_ascii_lower(cookie.domain) ||
        cookie.domain.contains(".")
      )
    }) &&
    request_path.has_prefix(cookie.path) &&
    (!cookie.secure || cookie_secure_context(url))
  })
  // The pinned Wget walks more-specific domain chains first, newest cookie
  // first within each chain. Its duplicate pass retains the last equal pair
  // before sorting by domain/path quality. Persistence retains chain order.
  {
    for index = 1; index < selected.length(); index = index + 1 {
      let cookie = selected[index]
      let mut position = index
      while position > 0 &&
            cookie.domain.length() > selected[position - 1].domain.length() {
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
  // Sending order must not change the domain-chain order used by persistence.
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
fn CookieJar::load_bytes(self : CookieJar, bytes : Bytes) -> Unit {
  self.load_octets_at(cookie_text(bytes), @fsops.current_timestamp().seconds)
}

///|
fn CookieJar::load_octets_at(
  self : CookieJar,
  text : String,
  now : Int64,
) -> Unit {
  for line in text.split("\n") {
    let line = line[:line.find("\u0000").unwrap_or(line.length())]
    let line = {
      let line = line.trim_start(chars=" \t\r\n\u{000b}\u{000c}")
      if line.has_suffix("\r") {
        line[:line.length() - 1].to_owned()
      } else {
        line.to_owned()
      }
    }
    if line == "" || line.has_prefix("#") {
      continue
    }
    let mut fields = line.split("\t").map(field => field.to_owned()).collect()
    if fields.length() > 7 {
      let value = fields[6:].to_owned().join("\t")
      fields = [..fields[:6], value]
    }
    if fields.length() != 7 {
      continue
    }
    if fields[:6].iter().any(field => field == "") {
      continue
    }
    let expires = {
      guard wget_cookie_number(fields[4]) is Some(value) else { continue }
      if value == 0.0 {
        None
      } else {
        if value < now.to_double() {
          continue
        }
        Some(wget_cookie_time(value))
      }
    }
    let (domain, port) = wget_cookie_domain_port(fields[0])
    let domain = cookie_stored_domain(domain)
    if domain == "" || fields[5] == "" {
      continue
    }
    let cookie : StoredCookie = {
      name: fields[5],
      value: fields[6],
      domain,
      host_only: fields[1] != "TRUE",
      port,
      path: fields[2],
      secure: fields[3] == "TRUE",
      expires,
    }
    self.replace(cookie)
  }
}

///|
fn CookieJar::netscape_octets(
  self : CookieJar,
  include_session~ : Bool = true,
  now~ : Int64 = @fsops.current_timestamp().seconds,
) -> String {
  let out = StringBuilder()
  out.write_string("# Netscape HTTP Cookie File\n# Generated by cli/core\n\n")
  let chains : Map[String, Array[StoredCookie]] = Map([])
  for cookie in self.entries {
    let domain = cookie_ascii_lower(cookie.domain)
    match chains.get(domain) {
      Some(chain) => chain.push(cookie)
      None => chains[domain] = [cookie]
    }
  }
  for domain in self.domains.cells {
    guard domain is Some(domain) else { continue }
    for cookie in chains[cookie_ascii_lower(domain)] {
      if cookie.expired(now) {
        continue
      }
      if !include_session && cookie.expires is None {
        continue
      }
      if !cookie.host_only {
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
      out.write_string(wget_cookie_saved_time(expiry))
      out.write_string("\t" + cookie.name + "\t" + cookie.value + "\n")
    }
  }
  out.to_string()
}

///|
pub async fn CookieJar::load(self : CookieJar, path : String) -> Unit {
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
