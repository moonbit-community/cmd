///|
test "effective child environment applies overrides and excludes secrets" {
  let inherited = {
    "LANG": "host-locale",
    "TZ": "host-zone",
    "HOME": "/private-user",
    "TOKEN": "secret",
  }
  let extra = {
    "LANG": "C",
    "TZ": "UTC",
    "LC_ALL": "POSIX",
    "TOKEN": "child-secret",
  }
  let profile = effective_environment(
    "/private-user/build/command", inherited, extra, true,
  )
  assert_eq(profile.program, "command")
  assert_eq(profile.values["LANG"], "C")
  assert_eq(profile.values["LC_ALL"], "POSIX")
  assert_eq(profile.values["TZ"], "UTC")
  let json = canonical_json(ToJson::to_json(profile))
  assert_false(json.contains("secret"))
  assert_false(json.contains("private-user"))
  let isolated = effective_environment("command", inherited, Map([]), false)
  assert_true(isolated.values.is_empty())
  let empty = effective_environment("command", inherited, { "LANG": "" }, true)
  assert_eq(empty.values["LANG"], "")
  assert_true(
    execution_environment_digest([profile]) !=
    execution_environment_digest([empty]),
  )
  assert_eq(
    execution_environment_digest([profile, empty]),
    execution_environment_digest([empty, profile]),
  )
}

///|
async test "spawn boundary records controlled environment instead of host defaults" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/usr/bin/true"])
  begin_environment_capture()
  defer begin_environment_capture()
  let result = run_with_deadline(
    "/usr/bin/true",
    [],
    1000,
    extra_env=controlled_environment({ "LC_ALL": "POSIX" }),
  )
  assert_eq(result.output.status, 0)
  let profiles = captured_execution_environments().filter(profile => {
    profile.program == "true" && profile.values.get("LC_ALL") == Some("POSIX")
  })
  assert_eq(profiles.length(), 1)
  assert_eq(profiles[0].values["LC_ALL"], "POSIX")
  assert_eq(profiles[0].values["LANG"], "C")
  assert_eq(profiles[0].values["TZ"], "UTC")
  let metadata = collect_run_metadata("environment-capture")
  assert_true(
    metadata.execution_environments.any(profile => {
      profile.program == "true" && profile.values.get("LC_ALL") == Some("POSIX")
    }),
  )
  assert_eq(
    metadata.environment_fingerprint,
    execution_environment_digest(metadata.execution_environments),
  )
}
