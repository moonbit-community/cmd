///|
async test "selected differential preserves the pinned image through both option parsers" {
  let root = @fs.tmpdir(prefix="cmd-selection-options-")
  defer @fs.rmdir(root, recursive=true)
  let current = @harness.run_with_deadline("git", ["rev-parse", "HEAD"], 15000)
  assert_eq(current.output.status, 0)
  let head = @utf8.decode(current.output.stdout).trim().to_owned()
  let selection : Json = {
    "schema": 1,
    "commit": head,
    "scope": "commands",
    "reason": "test selection",
    "commands": ["cat"],
    "case_ids": ["selected-cat"],
    "changed_paths": ["commands/cat/main.mbt"],
  }
  let path = root + "/selection.json"
  @fs.write_file(path, selection.stringify())
  let image = "sha256:" + "a".repeat(64)
  let oracle = @harness.parse_oracle_options([
    "--run-oracle-selection",
    path,
    root + "/report",
    "--oracle-image",
    image,
    "--oracle-profile",
    root + "/profile.json",
  ])
  let args = expand_oracle_selection(oracle.arguments)
  let parsed = parse_driver_options(args, root, root + "/manifest.json")
  assert_eq(parsed.oracle_image, image)
  assert_eq(parsed.ids, ["selected-cat"])
  assert_eq(parsed.suites, ["oracle"])
  assert_eq(parsed.jobs, 2)
  assert_eq(oracle.profile_path, root + "/profile.json")
  try
    expand_oracle_selection(["--run-oracle-selection", path, root + "/report"])
  catch {
    _ => ()
  } noraise {
    _ => fail("selected differential lost its pinned oracle")
  }
}

///|
async test "shared filesystem events select either consumer without duplicate alias execution" {
  let cases = @harness.load_cases(
    workspace_root() + "/tests/cases/manifest.json",
  )
  for command in ["find", "test"] {
    let selected = @harness.select_cases(cases, [command], []).filter(fixture => {
      case_in_suites(fixture, ["oracle"])
    })
    for
      id in [
        "metadata-relations", "f29-sparse-size", "f29-predicate-errors", "f29-special-kinds",
        "f29-subsecond-order",
      ] {
      assert_eq(
        selected.filter(fixture => fixture.id == id).length(),
        1,
        msg=command + ": " + id,
      )
    }
  }
  for
    (id, old_id) in [
      ("metadata-relations", "f29-metadata-selectors-oracle"),
      ("f29-subsecond-order", "f29-subsecond-order-oracle"),
      ("tee-output-errors", "tee-output-errors-oracle"),
      ("mktemp-option-effects", "mktemp-option-effects-oracle"),
    ] {
    let selected = @harness.select_cases(cases, [], [id, old_id])
    assert_eq(selected.map(fixture => fixture.id), [id])
    assert_true(case_in_suites(selected[0], ["oracle"]))
    assert_true(case_in_suites(selected[0], ["scenarios"]))
  }
}

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
  for path in ["commands/wget/moon.mod", "commands/wget/README.mbt.md"] {
    assert_eq(oracle_impact(Some([path]), commands, [fixture]).2, ["wget"])
  }
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
