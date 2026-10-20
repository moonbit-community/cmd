///|
test "published mv boundary preserves exact coordinates and observation requirements" {
  let manifest = {
    ..network_manifest_for_test(),
    release_scope: Some(["mv"]),
    commands: [
      {
        ..network_manifest_for_test().commands[0],
        name: "mv",
        package_name: "cli/mv",
      },
    ],
  }
  let launch = published_mv_launch(manifest, "selected-moonx")
  assert_eq(launch.program, "selected-moonx")
  assert_eq(launch.prefix, ["cli/mv@0.2.3", "--"])
  assert_eq(launch.source_version, "cli/mv@0.2.3")
  assert_true(launch.published)
  let fixture = {
    ..release_case_for_test("mv-windows-wasm-links-boundary", "mv"),
    comparison: Some("scenario"),
    host_platforms: Some(["windows"]),
  }
  assert_true(release_mv_scenario(fixture))
  assert_false(
    release_mv_scenario({ ..fixture, id: "mv-windows-native-links", }),
  )
  assert_true(explicit_host_contract(fixture, "windows"))
  assert_false(explicit_host_contract(fixture, "macos"))
  assert_true(requires_serial_fixture(fixture))
  let report : CaseReport = {
    id: fixture.id,
    command: "mv",
    version: "0.2.3",
    category: "boundary_passed",
    detail: "observed",
  }
  let shared = shared_report(report, [fixture], true, Map([]))
  assert_eq(shared.verification, "boundary")
  assert_eq(shared.backend, "published-wasm")
  for
    observation in [
      "symlink-target", "link-type", "referent-content", "unchanged-snapshot", "stdin-open",
    ] {
    assert_true(shared.observations.contains(observation))
  }
  assert_true(
    shared_report(
      { ..report, category: "runner_infra", },
      [fixture],
      true,
      Map([]),
    ).observations.is_empty(),
  )
  let rejected = try {
    ignore(
      published_mv_launch(
        { ..manifest, release_scope: Some(["curl"]), },
        "selected-moonx",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
