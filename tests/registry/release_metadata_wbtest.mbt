///|
test "release policy is included in registry identity and bound to owned cases" {
  let entry = entry_for_test("case:known", "json-case", "known")
  let command : ReleaseCommandMetadata = {
    name: "echo",
    package_name: "cli/echo",
    compare_profile: "gnu",
    supported_options: ["-n"],
    policy_sensitive: false,
    releasable: true,
    case_ids: Some(["known"]),
  }
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [command],
  }
  assert_true(validate(registry).is_empty())
  let changed = {
    ..registry,
    release_commands: [{ ..command, supported_options: ["-n", "-e"], }],
  }
  assert_true(
    @testkit.json_digest(registry.to_json()) !=
    @testkit.json_digest(changed.to_json()),
  )
  for
    invalid in [
      { ..command, package_name: "cli/cat", },
      { ..command, compare_profile: "", },
      { ..command, supported_options: ["-n", "-n"], },
      { ..command, case_ids: Some(["unknown"]), },
      { ..command, case_ids: Some(["known", "known"]), },
      { ..command, releasable: false, },
    ] {
    assert_false(
      validate({ ..registry, release_commands: [invalid], }).is_empty(),
    )
  }
  assert_false(
    validate({ ..registry, release_commands: [command, command], }).is_empty(),
  )
  assert_true(validate({ ..registry, release_commands: [], }).is_empty())
}

///|
test "registry schema requires explicit authoritative release metadata" {
  let missing = try {
    let _ : Registry = @json.from_json({ "schema": 2, "entries": [] })
    false
  } catch {
    _ => true
  }
  assert_true(missing)
  let legacy : Registry = { schema: 1, entries: [], release_commands: [], }
  assert_true(
    validate(legacy).any(message => message.contains("unsupported schema")),
  )
}

///|
test "release metadata migration preserves reviewed policy and refuses overwrite" {
  let entry = entry_for_test("case:known", "json-case", "known")
  let old : Json = { "schema": 1, "entries": [entry.to_json()] }
  let sidecar : Json = {
    "schema": 1,
    "commands": [
      {
        "name": "echo",
        "package_name": "cli/echo",
        "compare_profile": "reviewed-profile",
        "supported_options": ["-n"],
        "policy_sensitive": true,
        "releasable": true,
        "case_ids": ["known"],
      },
    ],
  }
  let migrated = migrate_release_metadata_document(old, sidecar)
  assert_eq(migrated.schema, 2)
  assert_eq(migrated.entries[0].to_json(), entry.to_json())
  assert_eq(migrated.release_commands[0].compare_profile, "reviewed-profile")
  assert_eq(migrated.release_commands[0].supported_options, ["-n"])
  assert_eq(migrated.release_commands[0].case_ids, Some(["known"]))
  assert_true(migrated.release_commands[0].policy_sensitive)
  assert_true(old is { "schema": Number(1, ..), .. })
  let repeated = try {
    ignore(migrate_release_metadata_document(migrated.to_json(), sidecar))
    false
  } catch {
    error => error.to_string().contains("unmigrated schema 1")
  }
  assert_true(repeated)
}
