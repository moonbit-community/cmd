///|
fn ParsedUrl::basic_credentials(
  self : ParsedUrl,
  options : TransferOptions,
) -> String? {
  let mut user = options.basic_user
  let mut password = options.basic_password
  if options.profile == WgetProfile && self.user_info is Some(info) {
    match info.split_once(":") {
      Some((name, secret)) => {
        user = Some(percent_decode(name.to_owned()))
        password = Some(percent_decode(secret.to_owned()))
      }
      None => user = Some(percent_decode(info))
    }
  }
  match (user, password) {
    (Some(user), Some(password)) => Some(user + ":" + password)
    (Some(user), None) if options.profile != WgetProfile => Some(user)
    _ => None
  }
}
