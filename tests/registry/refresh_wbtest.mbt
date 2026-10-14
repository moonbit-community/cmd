///|
test "package discovery preserves every reviewed field and stable identity" {
  let discovered = entry_for_test("discovered-name", "package-test", "")
  let reviewed : RegistryEntry = {
    ..discovered,
    behavior_id: "reviewed-stable-identity",
    aliases: ["previous-stable-identity"],
    command: "echo",
    owner: "reviewed-owner",
    surface: ["process", "stderr"],
    status: "boundary",
    coverage: ["reviewed-coverage", "operand"],
    required_backends: ["native", "wasm"],
    platforms: ["posix"],
    required_evidence: ["boundary", "upstream-differential"],
    observations: ["status", "stderr", "file-content"],
    oracle_profile: "reviewed-oracle-v3",
  }
  let release : ReleaseCommandMetadata = {
    name: "echo",
    package_name: "cli/echo",
    compare_profile: "gnu",
    supported_options: ["-n"],
    policy_sensitive: false,
    releasable: true,
    case_ids: Some([]),
  }
  let registry : Registry = {
    schema: 2,
    entries: [reviewed],
    release_commands: [release],
  }
  let refreshed = merge_package_test_bindings(registry, [discovered])
  assert_eq(
    @testkit.canonical_json(ToJson::to_json(refreshed)),
    @testkit.canonical_json(ToJson::to_json(registry)),
  )
  let again = merge_package_test_bindings(refreshed, [discovered])
  assert_eq(
    @testkit.canonical_json(ToJson::to_json(again)),
    @testkit.canonical_json(ToJson::to_json(registry)),
  )
  assert_true(validate(refreshed).is_empty())
}

///|
test "package discovery seeds only new bindings and rejects implicit removal" {
  let old = entry_for_test("reviewed-test", "package-test", "")
  let added = {
    ..old,
    behavior_id: "new-test",
    source: "tests/registry/new_wbtest.mbt::new",
  }
  let registry : Registry = { schema: 2, entries: [old], release_commands: [], }
  let refreshed = merge_package_test_bindings(registry, [old, added])
  assert_eq(refreshed.entries.length(), 2)
  assert_eq(refreshed.entries[0].behavior_id, old.behavior_id)
  assert_eq(refreshed.entries[1].to_json(), added.to_json())
  let removed = try {
    ignore(merge_package_test_bindings(registry, [added]))
    false
  } catch {
    error => error.to_string().contains("explicit identity migration")
  }
  assert_true(removed)
}

///|
async test "package refresh round trip preserves reviewed metadata on disk" {
  let root = @fs.tmpdir(prefix="mooncmd-registry-refresh")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  for directory in ["commands", "core", "tests", "tests/registry"] {
    @fs.mkdir(root + "/" + directory)
  }
  let config =
    #|supported_targets = "native"
  let source =
    #|test "stable test" {
    #|}
  @fs.write_file(root + "/tests/registry/moon.pkg", config)
  @fs.write_file(root + "/tests/registry/fixture_wbtest.mbt", source)
  let exception_file : Json = { "schema": 1, "exceptions": [] }
  @fs.write_file(
    root + "/tests/registry/platform-exceptions.json",
    exception_file.stringify(),
  )
  let reviewed = {
    ..entry_for_test("reviewed-identity", "package-test", ""),
    source: "tests/registry/fixture_wbtest.mbt::stable test",
    aliases: ["old-reviewed-identity"],
    coverage: ["strong-review"],
    observations: ["status", "stdout"],
  }
  let registry : Registry = {
    schema: 2,
    entries: [reviewed],
    release_commands: [],
  }
  @fs.write_file(root + "/registry.json", registry.to_json().stringify())
  let refreshed = refresh_package_tests(load(root + "/registry.json"), root~)
  @fs.write_file(root + "/registry.json", refreshed.to_json().stringify())
  let reloaded = load(root + "/registry.json")
  assert_eq(
    @testkit.canonical_json(reloaded.to_json()),
    @testkit.canonical_json(registry.to_json()),
  )
}
