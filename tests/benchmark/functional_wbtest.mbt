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
    Some("cli/diff@0.1.2"),
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
  prepare_input(left + "/large", 131073)
  prepare_input(right + "/large", 131073)
  assert_eq(compare_functional_effects(left, right, []), [])
  let file = @fs.open(right + "/large", mode=WriteOnly)
  file.write_at(b"x", position=131072L)
  file.close()
  assert_eq(compare_functional_effects(left, right, []), [
    "file content differs: large",
  ])
}

///|
async test "benchmark generated relations check mktemp identity and bounded yes prefixes" {
  let directory = @fs.tmpdir(prefix="cmd-functional-relations-")
  defer @fs.rmdir(directory, recursive=true)
  let root = directory + "/fixture"
  @fs.mkdir(root)
  let output = directory + "/stdout"
  if @testkit.host_platform() != "windows" {
    @fs.write_file(root + "/tmp.abcdef", b"", permission=384)
    @fs.write_file(output, "tmp.abcdef\n")
    assert_eq(check_generated_effects(Some("mktemp"), root, output), [])
    @fs.write_file(root + "/extra", "unexpected")
    assert_false(
      check_generated_effects(Some("mktemp"), root, output).is_empty(),
    )
  }
  let input = directory + "/yes-input"
  @fs.write_file(input, "y\n".repeat(3000))
  let reader = @fs.open(input, mode=ReadOnly)
  let capture = @fs.create(output)
  consume_yes(reader, capture, 4096)
  reader.close()
  capture.close()
  assert_eq(@fs.file_size(output), 4096L)
  assert_eq(check_generated_effects(Some("yes"), root, output), [])
  let changed = @fs.open(output, mode=WriteOnly)
  changed.write_at(b"x", position=4095L)
  changed.close()
  assert_false(check_generated_effects(Some("yes"), root, output).is_empty())
}

///|
async test "benchmark functional cases refuse metadata placeholders and retain declared root relations" {
  let metadata : @testkit.Case = @json.from_json({
    "id": "help",
    "command": "cat",
    "args": ["--help"],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  let workload : FunctionalWorkload = {
    id: "functional",
    command: "cat",
    reference_behavior_id: "case:help",
    case_id: Some("help"),
    recipe: None,
    pending: None,
    corpus: None,
  }
  let refused = Some(functional_fixture(workload, [metadata], "helper")) catch {
    _ => None
  }
  assert_true(refused is None)
  // Package tests run from the enclosing tests module.
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file("benchmark/functional.json").text()),
  )
  let cases = @testkit.load_cases("../" + manifest.case_corpus)
  assert_eq(manifest.workloads.length(), 79)
  for selected in manifest.workloads {
    let fixture = functional_fixture(selected, cases, "helper")
    assert_true(fixture.expected_status == 0 || fixture.expected_status == 1)
    assert_true(fixture.expected_rejection is None)
    if selected.recipe == Some("xargs-child") {
      assert_eq(fixture.args, [
        "-n", "1", "--", "helper", "--fixture-child", "emit",
      ])
    }
  }
  let directory = @fs.tmpdir(prefix="cmd-functional-root-")
  defer @fs.rmdir(directory, recursive=true)
  let generated = {
    ..workload,
    command: "realpath",
    case_id: None,
    recipe: Some("realpath"),
  }
  let fixture = functional_fixture(generated, [], "helper")
  let sides : Array[FunctionalSide] = []
  for name in ["left", "right"] {
    let root = directory + "/" + name
    reset_functional_fixture(root, fixture, "")
    let stdout = directory + "/" + name + ".stdout"
    let stderr = directory + "/" + name + ".stderr"
    @fs.write_file(stdout, root + "/f\n")
    @fs.write_file(stderr, b"")
    sides.push({
      root,
      stdout,
      stderr,
      errors: [],
      observation: {
        elapsed_us: 1.0,
        status: Some(0),
        timed_out: false,
        error: None,
      },
    })
  }
  assert_eq(compare_functional_sides(generated, fixture, sides[0], sides[1]), [])
  @fs.write_file(sides[1].stdout, sides[1].root + "/different\n")
  assert_false(
    compare_functional_sides(generated, fixture, sides[0], sides[1]).is_empty(),
  )
}
