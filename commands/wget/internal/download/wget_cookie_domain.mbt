///|
fn wget_cookie_domain_fallback(host : String, domain : String) -> Bool {
  let host = cookie_ascii_lower(host)
  let domain = cookie_ascii_lower(domain)
  if host == domain {
    return true
  }
  guard host.has_suffix(domain) else { return false }
  let labels = domain
    .strip_prefix(".")
    .unwrap_or(domain[:])
    .split(".")
    .to_array()
  let count = if labels.last() == Some("") {
    labels.length() - 1
  } else {
    labels.length()
  }
  guard count >= 2 && labels[:count].iter().all(label => !label.is_empty()) else {
    return false
  }
  if count == 2 &&
    ![".com", ".edu", ".net", ".org", ".gov", ".mil", ".int"]
    .iter()
    .any(suffix => domain.has_suffix(suffix)) &&
    @utf8.encode(labels[0]).length() <= 3 {
    return false
  }
  domain.has_prefix(".") || host.has_suffix("." + domain)
}

///|
fn wget_cookie_domain_allows(host : String, domain : String) -> Bool {
  // The fixed Linux Wget build disables NLS, so LC_CTYPE remains C. libpsl's
  // ASCII shortcut succeeds; non-ASCII conversion fails into Wget's heuristic.
  if !host.iter().all(character => character.to_int() < 128) ||
    !domain.iter().all(character => character.to_int() < 128) {
    return wget_cookie_domain_fallback(host, domain)
  }
  let host = cookie_ascii_lower(host)
  let domain = cookie_ascii_lower(domain).trim_start(chars=".").to_owned()
  host == domain ||
  (
    !@netops.cookie_ip_literal(host) &&
    host.has_suffix("." + domain) &&
    domain.length() > @netops.cookie_longest_suffix(host).length()
  )
}
