///|
fn cookie_suffix_allows(host : String, domain : String) -> Bool {
  let domain = domain.trim_start(chars=".").to_owned()
  host == domain ||
  (
    cookie_domain_matches(host, domain) &&
    domain.length() >
    @utf8.encode(@netops.cookie_longest_suffix(cookie_utf8(host))).length()
  )
}

///|
fn curl_suffix_name(domain : String) -> String {
  // The PSL view folds ASCII case and removes one trailing dot; storage keeps
  // the received spelling, including its case and dots.
  cookie_ascii_lower(
    if domain.has_suffix(".") {
      domain[:domain.length() - 1].to_owned()
    } else {
      domain
    },
  )
}

///|
fn curl_suffix_admission(host : String?, domain : String) -> Bool {
  if @netops.cookie_ip_literal(domain) {
    return true
  }
  let domain = curl_suffix_name(domain)
  if domain.length() >= 256 {
    return false
  }
  match host {
    Some(host) => {
      let host = curl_suffix_name(host)
      host.length() < 256 && cookie_suffix_allows(host, domain)
    }
    None =>
      domain == "localhost" ||
      !@netops.cookie_public_suffix(cookie_utf8(domain))
  }
}
