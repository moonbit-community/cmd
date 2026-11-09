///|
fn cookie_suffix_contains(rules : FixedArray[String], value : String) -> Bool {
  let mut low = 0
  let mut high = rules.length()
  while low < high {
    let middle = low + (high - low) / 2
    let comparison = rules[middle].lexical_compare(value)
    if comparison == 0 {
      return true
    } else if comparison < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  false
}

///|
pub fn cookie_public_suffix(domain : String) -> Bool {
  // libpsl's cookie policy includes both sections and wildcard bases. Its
  // prevailing '*' also treats unknown single-label domains as suffixes.
  let domain = if domain.has_prefix(".") {
    domain[1:].to_owned()
  } else {
    domain
  }
  let labels = domain.split(".").count()
  if labels > 255 {
    return false
  }
  if labels == 1 {
    return true
  }
  if cookie_suffix_contains(cookie_suffix_exception, domain) {
    return false
  }
  if cookie_suffix_contains(cookie_suffix_exact, domain) {
    return true
  }
  match domain.find(".") {
    Some(dot) =>
      cookie_suffix_contains(
        cookie_suffix_wildcard,
        domain[dot + 1:].to_owned(),
      )
    None => false
  }
}

///|
pub fn cookie_longest_suffix(host : String) -> String {
  // Match libpsl 0.21.2's bounded rightmost-nine-label search. Checking the
  // host from left to right is essential for non-contiguous listed suffixes
  // such as forgot.his.name and name, where his.name itself is not listed.
  let labels = host.split(".").map(label => label.to_owned()).to_array()
  let start = (labels.length() - 9).max(0)
  let mut domain = labels[start:].join(".")
  while !cookie_public_suffix(domain) {
    match domain.find(".") {
      Some(dot) => domain = domain[dot + 1:].to_owned()
      None => break
    }
  }
  domain
}

///|
fn cookie_ipv4_spelling(domain : String) -> Bool {
  domain.split(".").count() == 4 &&
  domain
  .split(".")
  .all(part => {
    !part.is_empty() &&
    (part.length() == 1 || !part.has_prefix("0")) &&
    part.iter().all(c => c >= '0' && c <= '9')
  })
}

///|
pub fn cookie_ip_literal(domain : String) -> Bool {
  if domain.contains("%") || domain.has_prefix("[") || domain.has_suffix("]") {
    return false
  }
  let address = if domain.contains(":") {
    if !domain
      .iter()
      .all(c => c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F' | ':' | '.')) {
      return false
    }
    if domain.contains(".") &&
      !cookie_ipv4_spelling(
        domain[domain.rev_find(":").unwrap() + 1:].to_owned(),
      ) {
      return false
    }
    "[" + domain + "]:0"
  } else {
    if !cookie_ipv4_spelling(domain) {
      return false
    }
    domain + ":0"
  }
  ignore(@socket.Addr::parse(address)) catch {
    _ => return false
  }
  true
}
