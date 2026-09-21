///|
fn sample_case(id : String, command : String) -> Case raise {
  @json.from_json({
    "id": id,
    "command": command,
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
}

///|
test "declared unordered output preserves duplicates and final newline" {
  assert_true(unordered_lines_equal(b"b\na\na\n", b"a\nb\na\n"))
  assert_false(unordered_lines_equal(b"b\na\n", b"a\nb\na\n"))
  assert_false(unordered_lines_equal(b"b\na", b"a\nb\n"))
  assert_false(unordered_lines_equal(b"\xff\n", b"\xff\n"))
}

///|
test "fixture substitutions preserve binary stdin and enforce every fragment" {
  let fixture = {
    ..sample_case("substitution", "cat"),
    comparison: Some("contract"),
    stdin_text: Some("${WORK}/input"),
    expected_stdout_text: Some("${WORK}/input"),
    expected_stderr_contains_all: Some(["first", "second"]),
    diagnostic_reason: Some("two independent diagnostic details"),
  }
  assert_eq(fixture.input(root="/case"), b"/case/input")
  assert_eq(
    check_contract(
      fixture,
      { status: 0, stdout: b"/case/input", stderr: b"first second", },
      "/case",
    ),
    [],
  )
  assert_false(
    check_contract(
      fixture,
      { status: 0, stdout: b"/case/input", stderr: b"first", },
      "/case",
    ).is_empty(),
  )
  let binary = { ..fixture, stdin_text: None, stdin_hex: Some("00ff"), }
  assert_eq(binary.input(root="/case"), b"\x00\xff")
}

///|
async test "file contracts detect changed content absent paths and wrong types" {
  let root = @fs.tmpdir(prefix="mooncmd-effects-test")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture : Case = @json.from_json({
    "id": "effects",
    "command": "cat",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "expected_files": [
      { "path": "file", "kind": "file", "content_hex": "00ff" },
      { "path": "missing", "exists": false },
    ],
  })
  @fs.write_file(root + "/file", b"\x00\xff")
  assert_eq(check_expected_files(fixture, root), [])
  @fs.write_file(root + "/file", b"changed")
  assert_true(
    check_expected_files(fixture, root).contains("file: content differs"),
  )
  @fs.write_file(root + "/missing", b"")
  assert_true(
    check_expected_files(fixture, root).contains("missing: unexpectedly exists"),
  )
  @fs.remove(root + "/file")
  @fs.mkdir(root + "/file")
  assert_true(
    check_expected_files(fixture, root).contains("file: type differs"),
  )
}

///|
test "selection uses union within fields and intersection across fields" {
  let a = sample_case("a", "true")
  let b = sample_case("b", "false")
  let c = sample_case("c", "true")
  assert_eq(
    select_cases([a, b, c], ["true"], ["b", "c"]).map(item => item.id),
    ["c"],
  )
  for
    (commands, ids) in [
      (["missing"], []),
      ([], ["missing"]),
      (["false"], ["a"]),
    ] {
    try select_cases([a, b, c], commands, ids) catch {
      _ => ()
    } noraise {
      _ => fail("invalid or empty selection accepted")
    }
  }
  let aliased = { ..a, aliases: Some(["old-a"]), }
  assert_eq(
    select_cases([aliased, b], [], ["old-a", "a"]).map(item => item.id),
    ["a"],
  )
}

///|
test "unverified metadata and excluded platforms cannot count as covered" {
  let fixture = {
    ..sample_case("metadata", "true"),
    comparison: Some("contract"),
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
    observe: Some(["mode"]),
  }
  assert_true(
    contract_errors(fixture).any(message => {
      message.contains("filesystem expectation")
    }),
  )
  assert_false(
    { ..fixture, host_platforms: Some(["excluded-platform"]), }.platform_applies(),
  )
  let entry : SnapshotEntry = {
    path: "file",
    kind: "file",
    content: b"data",
    metadata: { "mode": "600", "identity": "file" },
  }
  assert_true(snapshots_equal([entry], [entry]))
  assert_false(
    snapshots_equal([entry], [
      { ..entry, metadata: { "mode": "644", "identity": "file" }, },
    ]),
  )
  assert_false(
    snapshots_equal([entry], [
      { ..entry, metadata: { "mode": "600", "identity": "other" }, },
    ]),
  )
  assert_false(snapshots_equal([entry], [{ ..entry, content: b"changed", }]))
}

///|
test "contract requires assertions and distinguishes status 124 from deadline" {
  let empty = { ..sample_case("true", "true"), comparison: Some("contract"), }
  assert_eq(contract_errors(empty).length(), 2)
  let valid = {
    ..empty,
    expected_status: 124,
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
  }
  assert_eq(
    check_contract(valid, { status: 124, stdout: b"", stderr: b"", }, "/tmp"),
    [],
  )
  assert_false(
    check_contract(valid, { status: 0, stdout: b"", stderr: b"", }, "/tmp").is_empty(),
  )
  assert_false(
    check_contract(
      valid,
      { status: 124, stdout: b"wrong", stderr: b"", },
      "/tmp",
    ).is_empty(),
  )
  assert_false(
    check_contract(
      valid,
      { status: 124, stdout: b"", stderr: b"wrong", },
      "/tmp",
    ).is_empty(),
  )
}

///|
test "binary input and schema one fields remain lossless" {
  let old : Case = @json.from_json({
    "id": "old",
    "command": "cat",
    "args": [],
    "stdin_hex": "00ff",
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "delay_ms": 5,
    "timeout_ms": 10,
    "expected_rejection": "unavailable",
  })
  assert_eq(old.input(), b"\x00\xff")
  assert_eq(old.delay_ms, Some(5))
  assert_eq(old.timeout_ms, Some(10))
  assert_eq(old.expected_rejection, Some("unavailable"))
  try input_bytes(Some("61"), Some("a"), "ambiguous") catch {
    _ => ()
  } noraise {
    _ => fail("ambiguous input accepted")
  }
}

///|
test "availability boundary and skip cannot become semantic passes" {
  let report : CaseReport = {
    id: "true",
    command: "true",
    result: "pass",
    verification: "availability",
    stage: "complete",
    detail: "",
    platform: "linux",
    backend: "native",
    source_version: "test",
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    evidence: None,
  }
  assert_false(report.semantic_pass())
  assert_false({ ..report, verification: "boundary", }.semantic_pass())
  assert_false(
    { ..report, verification: "contract", result: "skip", }.semantic_pass(),
  )
  assert_false(
    { ..report, verification: "differential", missing_observations: ["mode"], }.semantic_pass(),
  )
  assert_true({ ..report, verification: "contract", }.semantic_pass())
}
