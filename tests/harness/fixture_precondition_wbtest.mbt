///|
fn readability_fixture(readable : Bool) -> Case raise {
  @json.from_json({
    "id": "readability-precondition",
    "command": "find",
    "args": [],
    "files": [
      { "path": "input", "content_text": "visible", "readable": readable },
    ],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
}

///|
async test "fixture readability prerequisites are checked before execution" {
  let root = @fs.tmpdir(prefix="mooncmd-readable-precondition")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  prepare_fixture(root, readability_fixture(true))
  let detail = try {
    prepare_fixture(root, readability_fixture(false))
    "incorrectly accepted"
  } catch {
    error => error.to_string()
  }
  assert_true(detail.contains("fixture precondition:"))
  assert_true(detail.contains("input: readable=false, observed=true"))
}

///|
async test "failed readability prerequisites remain fixture infrastructure failures" {
  let root = @fs.tmpdir(prefix="mooncmd-readable-report")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture = {
    ..readability_fixture(false),
    comparison: Some("contract"),
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
  }
  let report = execute_contract(
    fixture,
    root + "/missing-artifact",
    root + "/reports",
  )
  assert_eq(report.result, "infra")
  assert_eq(report.stage, "fixture")
  assert_true(report.detail.contains("fixture precondition:"))
  assert_false(report.semantic_pass())
}

///|
async test "implicit directory declarations preserve creation modes and reject mode overrides" {
  let root = @fs.tmpdir(prefix="mooncmd-parent-declaration-")
  defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
  let fixture : Case = @json.from_json({
    "id": "parent-declaration",
    "command": "find",
    "args": [],
    "files": [
      { "path": "parent/child", "content_text": "retained" },
      { "path": "parent", "kind": "directory" },
    ],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  prepare_fixture(root, fixture)
  assert_true(@fs.kind(root + "/parent", follow_symlink=false) is Directory)
  assert_eq(@fs.read_file(root + "/parent/child").text(), "retained")
  let overridden = {
    ..fixture,
    files: [{ ..fixture.files[1], mode: Some(0o777), }],
  }
  let detail = try {
    prepare_fixture(root, overridden)
    "incorrectly accepted"
  } catch {
    error => error.to_string()
  }
  assert_true(detail.contains("cannot override its creation mode"))
  assert_eq(@fs.read_file(root + "/parent/child").text(), "retained")
}
