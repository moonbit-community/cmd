///|
test "published consumers retain the explicit Moon account" {
  let environment = {
    "MOON_HOME": "/accounts/cli",
    "HOME": "/fixture/home",
    "USERPROFILE": "C:/fixture/home",
  }
  assert_eq(published_moon_home(environment, windows=false), "/accounts/cli")
  assert_eq(published_moon_home(environment, windows=true), "/accounts/cli")
  assert_eq(environment["HOME"], "/fixture/home")
}

///|
test "published consumers anchor the cache before fixture HOME overrides" {
  let environment = {
    "HOME": "/runner",
    "USERPROFILE": "C:/Users/runner",
    "MOON_HOME": "",
  }
  assert_eq(published_moon_home(environment, windows=false), "/runner/.moon")
  assert_eq(
    published_moon_home(environment, windows=true),
    "C:/Users/runner/.moon",
  )
}

///|
test "published consumers reject an unknown cache home" {
  for windows in [false, true] {
    try published_moon_home(Map([]), windows~) catch {
      _ => ()
    } noraise {
      _ => fail("missing home must not fall back to a fixture directory")
    }
  }
}
