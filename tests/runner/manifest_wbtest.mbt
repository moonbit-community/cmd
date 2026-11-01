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
    commands: @contracts.command_catalog().map(command => {
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
  }
  let unknown_kind : @testkit.FixtureFile = @json.from_json({
    "path": "link",
    "kind": "unknown-reparse-kind",
    "target": "target",
  })
  assert_true(
    validate_manifest({
      ..manifest,
      cases: [{ ..fixture, files: [unknown_kind], }],
    }).any(error => error.contains("unsupported fixture kind")),
  )
}

///|
test "manifest validation rejects empty case corpus and metadata that silently loses cases" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "selection-metadata",
    "command": "true",
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
    commands: @contracts.command_catalog().map(command => {
      name: command.name,
      baseline: "fixture",
      status: "unmeasured",
      wasm: "fixture",
      capabilities: [],
    }),
    cases: [fixture],
  }
  assert_eq(validate_manifest(manifest), [])
  assert_true(
    validate_manifest({ ..manifest, cases: [], }).contains(
      "manifest: required case corpus is empty",
    ),
  )
  for
    invalid in [
      { ..fixture, comparison: Some("contrcat"), },
      { ..fixture, host_platforms: Some([]), },
      { ..fixture, host_platforms: Some(["linx"]), },
      { ..fixture, expected_stderr_contains: Some(""), },
    ] {
    assert_false(
      validate_manifest({ ..manifest, cases: [invalid], }).is_empty(),
    )
  }
}
