///|
fn wire_cookie(value : String) -> @http.Cookie raise TransferError {
  let parts = value.split(";").to_array()
  guard parts[0].find("=") is Some(equal) else {
    raise transfer_error(ReceiveFailure, "invalid Set-Cookie field")
  }
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
          "max-age" =>
            max_age = Some(@string.parse_int64(value)) catch {
              _ =>
                raise transfer_error(ReceiveFailure, "invalid cookie Max-Age")
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
  )
}
