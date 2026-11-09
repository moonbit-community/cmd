///|
fn invalid_url(message : String) -> TransferError {
  @netops.TransferError(kind=InvalidUrl, message~, status=None, context=None)
}

///|
pub fn remote_name(url : String) -> String raise TransferError {
  let parsed = @netops.parse_absolute_url(url)
  let path = parsed.path.trim_end(chars="/").to_owned()
  if path == "" {
    return "index.html"
  }
  let name = match path.rev_find("/") {
    Some(index) => path[index + 1:].to_owned()
    None => path
  }
  let decoded = @netops.percent_decode(name)
  if decoded == "" || decoded == "." || decoded == ".." {
    "index.html"
  } else {
    decoded.replace_all(old="/", new="_").replace_all(old="\\", new="_")
  }
}

///|
pub fn proxy_bypassed(
  url : String,
  no_proxy : String?,
  utf8_hosts~ : Bool = true,
) -> Bool {
  guard no_proxy is Some(list) else { return false }
  let host = try
    @netops.parse_absolute_url(url).for_transfer(utf8_hosts~).socket_host()
  catch {
    _ => return false
  } noraise {
    value => value.to_lower()
  }
  for part in list.split(",") {
    let raw = part.trim().to_owned().to_lower()
    if raw == "" {
      continue
    }
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
