///|
test "runtime index rejects duplicate identities and invalid release selections" {
  let entry : RegistryEntry = {
    behavior_id: "case:echo-value",
    command: "echo",
    status: "supported",
    implementation: "json-case",
    source: "tests/cases/echo.json",
    case_id: "echo-value",
    aliases: ["old-echo"],
    platforms: [],
    oracle_profile: "",
  }
  let command : ReleaseCommandMetadata = {
    name: "echo",
    package_name: "cli/echo",
    compare_profile: "gnu",
    supported_options: ["help", "version"],
    policy_sensitive: false,
    releasable: true,
    case_ids: Some(["echo-value"]),
  }
  let index : Registry = {
    schema: 3,
    entries: [entry],
    release_commands: [command],
  }
  assert_eq(validate(index), [])
  assert_false(validate({ ..index, entries: [entry, entry], }).is_empty())
  assert_false(
    validate({ ..index, entries: [{ ..entry, aliases: [entry.behavior_id], }], }).is_empty(),
  )
  for
    invalid in [
      { ..command, package_name: "cli/cat", },
      { ..command, case_ids: Some(["missing"]), },
      { ..command, case_ids: Some(["echo-value", "echo-value"]), },
      { ..command, supported_options: ["help", "help"], },
    ] {
    assert_false(validate({ ..index, release_commands: [invalid], }).is_empty())
  }
}
