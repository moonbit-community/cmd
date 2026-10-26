///|
test "workspace manifest accepts explicit link kinds without accepting invalid fixtures" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "explicit-link",
    "command": "mv",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
    "comparison": "contract",
  })
  let manifest : Manifest = {
    schema: 2,
    commands: @cli.command_catalog().map(command => {
      name: command.name,
      baseline: "fixture",
      status: "unmeasured",
      wasm: "fixture",
      capabilities: [],
    }),
    cases: [],
  }
  for kind in ["symlink", "symbolic-link", "junction", "hardlink"] {
    let file : @testkit.FixtureFile = @json.from_json({
      "path": "link",
      "kind": kind,
      "target": "target",
    })
    assert_eq(
      validate_manifest({ ..manifest, cases: [{ ..fixture, files: [file], }], }),
      [],
    )
    let missing_target = { ..file, target: None, }
    assert_true(
      validate_manifest({
        ..manifest,
        cases: [{ ..fixture, files: [missing_target], }],
      }).any(error => error.contains("needs a target")),
    )
    let absolute_target = { ..file, target: Some("/outside"), }
    assert_true(
      validate_manifest({
        ..manifest,
        cases: [{ ..fixture, files: [absolute_target], }],
      }).any(error => error.contains("target must be relative")),
    )
    let unknown_kind = { ..file, kind: Some("unknown-reparse-kind"), }
    assert_true(
      validate_manifest({
        ..manifest,
        cases: [{ ..fixture, files: [unknown_kind], }],
      }).any(error => error.contains("unsupported fixture kind")),
    )
  }
}
