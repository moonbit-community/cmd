///|
test "published diff device boundary retains exact launch and actual observations" {
  let manifest = {
    ..network_manifest_for_test(),
    release_scope: Some(["diff"]),
    commands: [
      {
        ..network_manifest_for_test().commands[0],
        name: "diff",
        package_name: "cli/diff",
        version: "0.2.0",
      },
    ],
  }
  let fixture = {
    ..release_case_for_test("diff-directory-devices-boundary", "diff"),
    comparison: Some("scenario"),
    host_platforms: Some(["linux", "macos"]),
  }
  assert_true(release_diff_device_scenario(fixture))
  assert_false(
    release_diff_device_scenario({ ..fixture, comparison: Some("contract"), }),
  )
  assert_true(explicit_host_contract(fixture, "linux"))
  assert_true(explicit_host_contract(fixture, "macos"))
  assert_false(explicit_host_contract(fixture, "windows"))
  let launch = published_diff_device_launch(
    manifest, "selected-moonx", 15000, "/fixture",
  )
  assert_eq(launch.program, "selected-moonx")
  assert_eq(launch.args, ["cli/diff@0.2.0", "--", "-r", "left", "right"])
  assert_eq(launch.cwd, "/fixture")
  assert_eq(launch.stdin, b"")
  let report : CaseReport = {
    id: fixture.id,
    command: "diff",
    version: "0.2.0",
    category: "boundary_passed",
    detail: "observed",
  }
  let shared = shared_report(report, [fixture], true, Map([]))
  assert_eq(shared.verification, "boundary")
  for
    observation in ["status", "stdout", "stderr", "file-type", "symlink-target"] {
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
  let refused = try {
    ignore(
      published_diff_device_launch(
        { ..manifest, release_scope: Some(["curl"]), },
        "selected-moonx",
        15000,
        "/fixture",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(refused)
}
