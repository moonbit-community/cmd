///|
async test "real comparisons reject missing frozen artifacts before reading definitions" {
  require_frozen_timing_backend(Map([("--wasm-root", "/frozen")]))
  for sample in [false, true] {
    let reason = try {
      ignore(run_functional(Map([("--manifest", "/must-not-read")]), sample~))
      "accepted"
    } catch {
      error => error.to_string()
    }
    assert_true(reason.contains("require explicit frozen Wasm artifacts"))
  }
}

///|
test "benchmark direct Wasm invocation preserves program arguments" {
  let (wasm_root, wasm_artifact) = if @async.platform is Windows {
    ("C:\\artifacts", "C:\\artifacts\\cli\\diff\\diff.wasm")
  } else {
    ("/artifacts", "/artifacts/cli/diff/diff.wasm")
  }
  let options = Map([
    ("--wasm-root", wasm_root),
    ("--moonrun", "/tools/moonrun"),
  ])
  let (program, args) = functional_candidate(
    "diff",
    ["-u", "a file", "b"],
    options,
  )
  assert_eq(program, "/tools/moonrun")
  assert_eq(args, [wasm_artifact, "--", "-u", "a file", "b"])
}

///|
async test "benchmark functional fixtures reset mutations and compare bounded effects" {
  let directory = @fs.tmpdir(prefix="cmd-functional-reset-")
  defer @fs.rmdir(directory, recursive=true)
  let fixture : @testkit.Case = @json.from_json({
    "id": "reset",
    "command": "cat",
    "args": [],
    "files": [{ "path": "f", "content_text": "original" }],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  let left = directory + "/left"
  let right = directory + "/right"
  reset_functional_fixture(left, fixture, "")
  reset_functional_fixture(right, fixture, "")
  @fs.write_file(left + "/f", "changed")
  @fs.write_file(left + "/extra", "not in fixture")
  assert_false(compare_functional_effects(left, right, []).is_empty())
  reset_functional_fixture(left, fixture, "")
  assert_eq(@fs.read_file(left + "/f").text(), "original")
  assert_false(@fs.exists(left + "/extra"))
  assert_eq(compare_functional_effects(left, right, []), [])
  write_observer_input(left + "/large", 131073)
  write_observer_input(right + "/large", 131073)
  assert_eq(compare_functional_effects(left, right, []), [])
  let file = @fs.open(right + "/large", mode=WriteOnly)
  file.write_at(b"x", position=131072L)
  file.close()
  assert_eq(compare_functional_effects(left, right, []), [
    "file content differs: large",
  ])
}

///|
test "real fixture builder rejects metadata operations" {
  for args in [["--help"], ["--version"]] {
    let row : FunctionalWorkload = @json.from_json({
      "id": "metadata",
      "command": "cat",
      "reference_behavior_id": "case:cat",
      "recipe": "real-input",
      "args": Json(args),
      "expected_status": 0,
    })
    let accepted = Some(functional_fixture(row)) catch { _ => None }
    assert_true(accepted is None)
  }
}
