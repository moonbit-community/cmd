///|
fn wire_cookie(value : String, profile : TransferProfile) -> @http.Cookie? {
  let parts = value.split(";").to_array()
  guard parts[0].find("=") is Some(equal) else { return None }
  let name = parts[0][:equal].to_owned()
  let content = parts[0][equal + 1:].to_owned()
  let mut path = None
  let mut expires_raw = None
  let mut max_age = None
  let mut domain = None
  let mut secure = false
  let mut http_only = false
  let extensions : Array[String] = []
  for part in parts[1:] {
    let part = part.trim().to_owned()
    match part.find("=") {
      Some(equal) => {
        let value = part[equal + 1:].to_owned()
        match part[:equal].to_lower() {
          "path" => path = Some(value)
          "expires" => expires_raw = Some(value)
          "domain" => domain = Some(value)
          "max-age" => {
            if profile == WgetProfile && @utf8.encode(value).length() >= 32 {
              return None
            }
            let parsed = Some(@string.parse_int64(value)) catch { _ => None }
            match parsed {
              Some(age) => max_age = Some(age)
              None => {
                let positive_overflow = value != "" &&
                  value
                  .iter()
                  .all(character => character >= '0' && character <= '9')
                if profile == CurlProfile {
                  // Positive decimal overflow saturates; malformed text expires
                  // this cookie, including a previously stored value in its scope.
                  max_age = Some(
                    if positive_overflow {
                      9223372036854775807L
                    } else {
                      0L
                    },
                  )
                } else if profile == WgetProfile && positive_overflow {
                  // The pinned Wget numeric conversion expires these values;
                  // nonnumeric or overlong attributes discard only this cookie.
                  max_age = Some(0L)
                } else {
                  // Ignoring the invalid cookie preserves an earlier value;
                  // it must not become a new session cookie.
                  return None
                }
              }
            }
          }
          _ => extensions.push(part)
        }
      }
      None =>
        match part.to_lower() {
          "secure" => secure = true
          "httponly" => http_only = true
          _ => extensions.push(part)
        }
    }
  }
  Some(
    @http.Cookie(
      name,
      content,
      path?,
      expires_raw?,
      max_age?,
      domain?,
      secure~,
      http_only~,
      extensions~,
    ),
  )
}
