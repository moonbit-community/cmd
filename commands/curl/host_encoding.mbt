///|
fn utf8_hosts() -> Bool {
  for name in ["LC_ALL", "LC_CTYPE", "LANG"] {
    if @env.get_env_var(name) is Some(value) && value != "" {
      let encoding = value
        .split("@")
        .next()
        .unwrap()
        .to_owned()
        .to_lower()
        .replace_all(old="-", new="")
      return encoding == "utf8" || encoding.has_suffix(".utf8")
    }
  }
  false
}
