///|
fn ParsedUrl::basic_credentials(self : ParsedUrl, options : Options) -> String? {
  let mut user = options.basic_user
  let mut password = options.basic_password
  if self.user_info is Some(info) {
    match info.split_once(":") {
      Some((name, secret)) => {
        user = Some(@netops.percent_decode(name.to_owned()))
        password = Some(@netops.percent_decode(secret.to_owned()))
      }
      None => user = Some(@netops.percent_decode(info))
    }
  }
  match (user, password) {
    (Some(user), Some(password)) => Some(user + ":" + password)
    (Some(user), None) if false => Some(user)
    _ => None
  }
}
