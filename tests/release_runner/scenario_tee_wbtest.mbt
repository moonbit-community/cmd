///|
test "published tee pipe scenarios bind exact coordinates and observed dimensions" {
  let manifest = {
    ..network_manifest_for_test(),
    release_scope: Some(["tee"]),
    commands: [
      {
        ..network_manifest_for_test().commands[0],
        name: "tee",
        package_name: "cli/tee",
        version: "0.2.2",
      },
    ],
  }
  let launch = published_tee_launch(manifest, "chosen-moonx", 15000, "/fixture")
  assert_eq(launch.program, "chosen-moonx")
  assert_eq(launch.args, ["cli/tee@0.2.2", "--"])
  assert_eq(launch.cwd, "/fixture")
  let fixture = {
    ..release_case_for_test("tee-default-pipe-boundary", "tee"),
    comparison: Some("scenario"),
  }
  assert_true(release_tee_scenario(fixture))
  assert_false(release_tee_scenario({ ..fixture, id: "other", }))
  let report : CaseReport = {
    id: fixture.id,
    command: "tee",
    version: "0.2.2",
    category: "boundary_passed",
    detail: "actual closed pipe",
  }
  let shared = shared_report(report, [fixture], true, Map([]))
  assert_eq(shared.verification, "boundary")
  assert_true(shared.observations.contains("stderr"))
  assert_true(shared.observations.contains("file-content"))
  assert_false(shared.observations.contains("stdout"))
  assert_true(
    shared_report(
      { ..report, category: "runner_infra", },
      [fixture],
      true,
      Map([]),
    ).observations.is_empty(),
  )
}
