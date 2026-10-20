///|
test "explicit host contracts retain platform and oracle requirements" {
  let fixture = {
    ..release_case_for_test("windows-link-boundary", "mv"),
    host_platforms: Some(["windows"]),
    comparison: Some("boundary"),
  }
  assert_true(explicit_host_contract(fixture, "windows"))
  assert_false(explicit_host_contract(fixture, "macos"))
  assert_false(explicit_host_contract(fixture, "linux"))
  assert_false(
    explicit_host_contract({ ..fixture, oracle: Some(true), }, "windows"),
  )
  assert_false(
    explicit_host_contract({ ..fixture, host_platforms: None, }, "windows"),
  )
  assert_false(
    explicit_host_contract(
      { ..fixture, comparison: Some("differential"), },
      "windows",
    ),
  )
  assert_true(
    explicit_host_contract(
      { ..fixture, comparison: Some("contract"), },
      "windows",
    ),
  )
}

///|
async test "scoped Windows acceptance selects both mv link contracts" {
  let root = workspace_root()
  let manifest = read_release_manifest(
    root + "/tests/release_runner/current/candidate.json",
  )
  let base = read_base_manifest(
    root + "/tests/release_runner/current/active-cases.json",
  )
  let scoped = { ..manifest, release_scope: Some(["curl", "mv", "wget"]), }
  let selected = release_cases(scoped, base).filter(fixture => {
    explicit_host_contract(fixture, "windows")
  })
  let ids = selected.map(fixture => fixture.id)
  ids.sort_by((left, right) => left.lexical_compare(right))
  assert_eq(ids, [
    "async-0225-mv-windows-junction-no-clobber", "async-0225-mv-windows-symbolic-link-no-clobber",
    "mv-windows-wasm-links-boundary",
  ])
  assert_true(selected.all(fixture => fixture.command == "mv"))
  let full = { ..manifest, release_scope: None, }
  let all = release_cases(full, base)
    .filter(fixture => explicit_host_contract(fixture, "windows"))
    .map(fixture => fixture.id)
  for
    old in [
      "compat-filesystem-windows-chmod-boundary", "compat-filesystem-windows-ln-boundary",
      "rm-final-parent-backslash", "repair-which-windows-pathext",
    ] {
    assert_true(all.contains(old))
  }
}
