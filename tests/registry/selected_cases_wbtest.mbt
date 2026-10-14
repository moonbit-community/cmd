///|
fn selected_fixture() -> @testkit.Case raise {
  @json.from_json({
    "id": "known",
    "command": "echo",
    "args": ["contract"],
    "files": [],
    "environment": { "LANG": "C", "TZ": "UTC" },
    "expected_status": 0,
    "normalizations": [],
    "comparison": "contract",
    "expected_stdout_text": "contract\n",
    "expected_stderr_text": "",
  })
}

///|
async test "selected cases require registered IDs and unchanged canonical bodies" {
  let root = @fs.tmpdir(prefix="mooncmd-selected-cases")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture = selected_fixture()
  let source : Json = { "schema": 1, "cases": [fixture.to_json()] }
  @fs.write_file(root + "/source.json", source.stringify())
  let entry = {
    ..entry_for_test("case:known", "json-case", "known"),
    source: "source.json",
  }
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  assert_true(validate_selected_cases(registry, [fixture], root~).is_empty())
  let unknown = { ..fixture, id: "unregistered", }
  assert_true(
    validate_selected_cases(registry, [unknown], root~).any(message => {
      message.contains("unregistered selected case")
    }),
  )
  let substituted = {
    ..fixture,
    args: ["weakened"],
    expected_stdout_text: None,
  }
  assert_true(
    validate_selected_cases(registry, [substituted], root~).any(message => {
      message.contains("differs from registered source")
    }),
  )
  let changed_environment = {
    ..fixture,
    environment: { "TZ": "UTC", "LANG": "C" },
  }
  assert_true(
    validate_selected_cases(registry, [changed_environment], root~).is_empty(),
  )
  assert_true(
    validate_selected_cases(registry, [fixture, fixture], root~).any(message => {
      message.contains("duplicate selected case")
    }),
  )
}

///|
async test "selected case aliases cannot substitute the canonical identity" {
  let root = @fs.tmpdir(prefix="mooncmd-selected-aliases")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture = { ..selected_fixture(), aliases: Some(["legacy-known"]), }
  let source : Json = { "schema": 1, "cases": [fixture.to_json()] }
  @fs.write_file(root + "/source.json", source.stringify())
  let entry = {
    ..entry_for_test("case:known", "json-case", "known"),
    source: "source.json",
    aliases: ["legacy-known"],
  }
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  assert_true(validate_selected_cases(registry, [fixture], root~).is_empty())
  let alias_body = { ..fixture, id: "legacy-known", }
  assert_true(
    validate_selected_cases(registry, [alias_body], root~).any(message => {
      message.contains("differs from registered source")
    }),
  )
  let duplicated = {
    ..registry,
    entries: [entry, { ..entry, behavior_id: "other", }],
  }
  assert_true(
    validate_selected_cases(duplicated, [fixture], root~).any(message => {
      message.contains("ambiguous selected case")
    }),
  )
  @fs.remove(root + "/source.json")
  assert_true(
    validate_selected_cases(registry, [fixture], root~).any(message => {
      message.contains("source unavailable")
    }),
  )
}
