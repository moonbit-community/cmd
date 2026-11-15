///|
fn published_moon_home(
  environment : Map[String, String],
  windows~ : Bool,
) -> String raise {
  if environment.get("MOON_HOME") is Some(value) && !value.is_empty() {
    return value
  }
  let home_key = if windows { "USERPROFILE" } else { "HOME" }
  guard environment.get(home_key) is Some(home) && !home.is_empty() else {
    fail("published acceptance requires MOON_HOME or " + home_key)
  }
  home + "/.moon"
}
