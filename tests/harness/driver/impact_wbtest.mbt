///|
test "impact selection keeps rename sources and destinations and fails closed" {
  assert_eq(
    changed_paths(
      "R100\u0000commands/curl/a.mbt\u0000commands/wget/a.mbt\u0000D\u0000tests/fixtures/network/deleted.json\u0000",
    ),
    [
      "commands/curl/a.mbt", "commands/wget/a.mbt", "tests/fixtures/network/deleted.json",
    ],
  )
  for
    malformed in ["M\u0000", "M\u0000x", "Z\u0000x\u0000", "R100\u0000x\u0000"] {
    try changed_paths(malformed) catch {
      _ => ()
    } noraise {
      _ => fail("malformed change list passed")
    }
  }
  let commands = ["curl", "wget"]
  let fixture : @harness.Case = @json.from_json({
    "id": "cookies",
    "command": "curl",
    "related_commands": ["wget"],
    "inputs": ["tests/fixtures/network/cookies.json"],
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
  })
  for
    path in [
      "core/netops/url.mbt", "moon.work", "tests/harness/driver/impact.mbt", "tests/fixtures/unknown.json",
      ".github/workflows/check.yml",
    ] {
    assert_eq(oracle_impact(Some([path]), commands, [fixture]).0, "all")
  }
  assert_eq(oracle_impact(None, commands, [fixture]).0, "all")
  assert_eq(oracle_impact(Some([]), commands, [fixture]).0, "all")
  assert_eq(
    oracle_impact(Some(["README.md", "commands/curl/README.md"]), commands, [
      fixture,
    ]).0,
    "none",
  )
  assert_eq(
    oracle_impact(Some(["commands/wget/moon.mod"]), commands, [fixture]).2,
    ["wget"],
  )
  assert_eq(
    oracle_impact(Some(["tests/cases/curl.json"]), commands, [fixture]).2,
    ["curl"],
  )
  assert_eq(
    oracle_impact(Some(["tests/fixtures/network/cookies.json"]), commands, [
      fixture,
    ]).2,
    commands,
  )
}

///|
async test "registered fixture absence cannot disappear from a selected run" {
  let root = @fs.tmpdir(prefix="oracle-input-test-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/present.json", "{}")
  let fixture : @harness.Case = @json.from_json({
    "id": "fixture",
    "command": "cat",
    "args": [],
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
  })
  validate_case_inputs(root, [{ ..fixture, inputs: Some(["present.json"]), }])
  for
    inputs in [
      ["absent.json"],
      ["present.json", "present.json"],
      ["../outside"],
    ] {
    try
      validate_case_inputs(root, [{ ..fixture, inputs: Some(inputs), }])
    catch {
      _ => ()
    } noraise {
      _ => fail("invalid fixture input passed")
    }
  }
}
