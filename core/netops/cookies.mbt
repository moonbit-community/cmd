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
fn cookie_domain_matches(host : String, domain : String) -> Bool {
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
  let mut day : Int? = None
  let mut month : Int? = None
  let mut year : Int? = None
  let mut clock : (Int, Int, Int)? = None
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
) -> Unit {
  let mut index : Int? = None
  for position, old in self.entries {
    if old.name == cookie.name &&
      old.domain == cookie.domain &&
      old.path == cookie.path {
      index = Some(position)
      break
    }
  }
  if cookie.expires is Some(expiry) && expiry <= now {
    self.entries = self.entries.filter(old => {
      !(old.name == cookie.name &&
      old.domain == cookie.domain &&
      old.path == cookie.path)
    })
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
  cookies : Array[@http.Cookie],
  now : Int64,
) -> Unit {
  let host = url.host.to_lower()
  for cookie in cookies {
    if cookie.name == "" ||
      cookie.name.contains("\t") ||
      cookie.value.contains("\t") {
      continue
    }
    let (domain, host_only) = match cookie.domain {
      Some(domain) if domain != "" => {
        let domain = domain.trim_start(chars=".").to_owned().to_lower()
        if domain == "" || !cookie_domain_matches(host, domain) {
          continue
        }
        (domain, false)
      }
      _ => (host, true)
    }
    let path = match cookie.path {
      Some(path) if path.has_prefix("/") => path
      _ => default_cookie_path(url.path)
    }
    let expires = match cookie.max_age {
      Some(age) if age <= 0L => Some(0L)
      Some(age) => Some(now + age.min(9223372036854775807L - now))
      None =>
        match cookie.expires_raw {
          Some(value) => cookie_date(value)
          None => None
        }
    }
    self.replace(
      {
        name: cookie.name,
        value: cookie.value,
        domain,
        host_only,
        path,
        secure: cookie.secure,
        http_only: cookie.http_only,
        expires,
      },
      now,
    )
  }
}

///|
fn CookieJar::header_for(
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
  let host = url.host.to_lower()
  let selected = self.entries.filter(cookie => {
    (if cookie.host_only {
      host == cookie.domain
    } else {
      cookie_domain_matches(host, cookie.domain)
    }) &&
    cookie_path_matches(url.path, cookie.path) &&
    (!cookie.secure || url.scheme == "https")
  })
  // Insertion sort preserves creation order among equally specific paths.
  for index = 1; index < selected.length(); index = index + 1 {
    let cookie = selected[index]
    let mut position = index
    while position > 0 &&
          selected[position - 1].path.length() < cookie.path.length() {
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
pub fn CookieJar::load_netscape(self : CookieJar, text : String) -> Unit {
  let now = @fsops.current_timestamp().seconds
  for line in text.split("\n") {
    let line = line.trim_end(chars="\r").to_owned()
    let http_only = line.has_prefix("#HttpOnly_")
    let line = if http_only { line[10:].to_owned() } else { line }
    if line == "" || line.has_prefix("#") {
      continue
    }
    let fields = line.split("\t").map(field => field.to_owned()).collect()
    if fields.length() != 7 {
      continue
    }
    let expires = @string.parse_int64(fields[4]) catch { _ => continue }
    let domain = fields[0].trim_start(chars=".").to_owned().to_lower()
    if domain == "" || !fields[2].has_prefix("/") || fields[5] == "" {
      continue
    }
    self.replace(
      {
        name: fields[5],
        value: fields[6],
        domain,
        host_only: fields[1].to_upper() != "TRUE",
        path: fields[2],
        secure: fields[3].to_upper() == "TRUE",
        http_only,
        expires: if expires == 0L {
          None
        } else {
          Some(expires)
        },
      },
      now,
    )
  }
}

///|
pub fn CookieJar::netscape(
  self : CookieJar,
  include_session? : Bool = true,
) -> String {
  let now = @fsops.current_timestamp().seconds
  let out = StringBuilder()
  out.write_string("# Netscape HTTP Cookie File\n# Generated by cli/core\n\n")
  for cookie in self.entries {
    if cookie.expires is Some(expiry) && expiry <= now {
      continue
    }
    if !include_session && cookie.expires is None {
      continue
    }
    if cookie.http_only {
      out.write_string("#HttpOnly_")
    }
    if !cookie.host_only {
      out.write_string(".")
    }
    out.write_string(cookie.domain)
    out.write_string(if cookie.host_only { "\tFALSE\t" } else { "\tTRUE\t" })
    out.write_string(cookie.path)
    out.write_string(if cookie.secure { "\tTRUE\t" } else { "\tFALSE\t" })
    out.write_string(cookie.expires.unwrap_or(0L).to_string())
    out.write_string("\t" + cookie.name + "\t" + cookie.value + "\n")
  }
  out.to_string()
}

///|
pub async fn CookieJar::load(self : CookieJar, path : String) -> Unit {
  self.load_netscape(@fs.read_file(path).text())
}

///|
pub async fn CookieJar::save(
  self : CookieJar,
  path : String,
  include_session? : Bool = true,
) -> Unit {
  let text = self.netscape(include_session~)
  if path == "-" {
    @stdio.stdout.write(text)
  } else {
    @fs.write_file(path, text, permission=0o666)
  }
}
