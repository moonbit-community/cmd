///|
fn selection_entry_for_test(
  id : String,
  backends : Array[String],
) -> @registry.RegistryEntry {
  {
    behavior_id: "package-test:" + id,
    command: "",
    owner: "tests/fixture",
    surface: [],
    status: "supported",
    implementation: "package-test",
    source: "tests/fixture/fixture_wbtest.mbt::" + id,
    case_id: "",
    aliases: [],
    coverage: [],
    required_backends: backends,
    platforms: [],
    required_evidence: if backends.contains("native") &&
      backends.contains("wasm") {
      ["contract", "backend-pair"]
    } else {
      ["contract"]
    },
    observations: ["status"],
    oracle_profile: "",
  }
}

///|
test "package native-only selection requires native all mode" {
  validate_native_only_selection("native", true, true)
  validate_native_only_selection("pair", true, false)
  validate_native_only_selection("wasm", false, false)
  for (backend, all) in [("pair", true), ("wasm", true), ("native", false)] {
    assert_true(
      try {
        validate_native_only_selection(backend, all, true)
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "package native-only and pair selectors partition applicable native tests" {
  let native = selection_entry_for_test("native", ["native"])
  let dual = selection_entry_for_test("dual", ["wasm", "native"])
  let wasm = selection_entry_for_test("wasm", ["wasm"])
  let entries = [native, dual, wasm]
  let only = entries.filter(entry => {
    package_all_selected(entry, "native", "linux", true)
  })
  let pair = entries.filter(entry => {
    package_all_selected(entry, "pair", "linux", false)
  })
  assert_eq(only.map(entry => entry.behavior_id), [native.behavior_id])
  assert_eq(pair.map(entry => entry.behavior_id), [dual.behavior_id])
  assert_eq(
    entries
    .filter(entry => package_all_selected(entry, "native", "linux", false))
    .map(entry => entry.behavior_id),
    [native.behavior_id, dual.behavior_id],
  )
  assert_false(
    only.any(entry => {
      pair.any(paired => paired.behavior_id == entry.behavior_id)
    }),
  )
}

///|
test "package native-only selection preserves platform and implementation restrictions" {
  let entry = {
    ..selection_entry_for_test("posix", ["native"]),
    platforms: ["posix"],
  }
  assert_true(package_all_selected(entry, "native", "linux", true))
  assert_true(package_all_selected(entry, "native", "macos", true))
  assert_false(package_all_selected(entry, "native", "windows", true))
  assert_false(
    package_all_selected(
      { ..entry, implementation: "metadata-probe", },
      "native",
      "linux",
      true,
    ),
  )
  assert_false(package_all_selected(entry, "wasm", "linux", true))
  assert_false(package_all_selected(entry, "pair", "linux", true))
}
