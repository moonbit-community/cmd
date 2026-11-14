///|
fn parse_cookie_octets(value : String) -> Cookie? {
  guard value.length() <= MaxCookieLineBytes else { return None }
  let value = match value.find("\r") {
    Some(end) => value[:end].to_owned()
    None => value
  }
  let parts = value.split(";").to_array()
  guard parts[0].find("=") is Some(equal) else { return None }
  let name = parts[0][:equal].trim(chars=" \t").to_owned()
  let content = parts[0][equal + 1:].trim(chars=" \t").to_owned()
  guard !name.is_empty() &&
    name.length() + content.length() <= MaxCookiePairBytes &&
    !cookie_control(name) &&
    !cookie_control(content) else {
    return None
  }
  let mut path = None
  let mut expires_raw = None
  let mut max_age = None
  let mut domain = None
  let mut secure = false
  let mut http_only = false
  for part in parts[1:] {
    let part = part.trim(chars=" \t").to_owned()
    match part.find("=") {
      Some(equal) => {
        let value = part[equal + 1:].trim(chars=" \t").to_owned()
        let attribute = part[:equal].trim(chars=" \t").to_owned()
        guard !cookie_control(attribute) && !cookie_control(value) else {
          return None
        }
        match attribute.to_lower() {
          "path" => path = Some(value)
          "expires" => if value != "" { expires_raw = Some(value) }
          "domain" => if value != "" { domain = Some(value) }
          "max-age" => {
            if value == "" {
              continue
            }
            let parsed = Some(@string.parse_int64(value)) catch { _ => None }
            match parsed {
              Some(age) => max_age = Some(age)
              None => {
                let positive_overflow = value != "" &&
                  value
                  .iter()
                  .all(character => character >= '0' && character <= '9')
                // Positive decimal overflow saturates; malformed text expires
                // this cookie, including a previously stored value in its scope.
                max_age = Some(
                  if positive_overflow {
                    9223372036854775807L
                  } else {
                    0L
                  },
                )
              }
            }
          }
          _ => ()
        }
      }
      None => {
        guard !cookie_control(part) else { return None }
        match part.to_lower() {
          "secure" => secure = true
          "httponly" => http_only = true
          _ => ()
        }
      }
    }
  }
  Some({
    name,
    value: content,
    path,
    expires_raw,
    max_age,
    domain,
    secure,
    http_only,
  })
}

///|
fn cookie_control(value : String) -> Bool {
  value.iter().any(character => character < ' ' || character == '\u007f')
}
