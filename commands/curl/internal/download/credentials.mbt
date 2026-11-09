///|
fn basic_credentials(options : Options) -> String? {
  let user = options.basic_user
  let password = options.basic_password
  match (user, password) {
    (Some(user), Some(password)) => Some(user + ":" + password)
    (Some(user), None) if true => Some(user)
    _ => None
  }
}
