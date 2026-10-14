///|
test "dual backend supported contracts require actual pair evidence across implementations" {
  for
    kind in ["package-test", "metadata-probe", "stateful-scenario", "json-case"] {
    let entry = {
      ..entry_for_test(
        "reviewed",
        kind,
        if kind == "json-case" {
          "fixture"
        } else {
          ""
        },
      ),
      required_backends: ["native", "wasm"],
      required_evidence: ["contract"],
    }
    let registry : Registry = {
      schema: 2,
      entries: [entry],
      release_commands: [],
    }
    assert_true(
      validate(registry).any(error => error.contains("requires backend-pair")),
    )
    assert_false(
      validate({
        ..registry,
        entries: [{ ..entry, required_evidence: ["contract", "backend-pair"], }],
      }).any(error => error.contains("requires backend-pair")),
    )
  }
}

///|
test "single backend and rejection evidence do not invent a pair requirement" {
  let entry = entry_for_test("one-target", "package-test", "")
  assert_false(entry.requires_backend_pair())
  assert_false(
    {
      ..entry,
      status: "boundary",
      required_backends: ["native", "wasm"],
      required_evidence: ["boundary"],
    }.requires_backend_pair(),
  )
  assert_false(
    {
      ..entry,
      required_backends: ["native", "wasm"],
      required_evidence: ["upstream-differential"],
    }.requires_backend_pair(),
  )
}

///|
async test "command discovery ignores regular files beside command directories" {
  let root = @fs.tmpdir(prefix="mooncmd-registry-command-discovery")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/.DS_Store", "finder metadata")
  @fs.write_file(root + "/notes.txt", "not a command")
  @fs.mkdir(root + "/registered")
  @fs.mkdir(root + "/not-a-module")
  @fs.write_file(root + "/registered/moon.mod", "name = \"cli/registered\"\n")
  assert_eq(command_names(root), ["registered"])
}

///|
test "frozen registry validation preserves historical requirements but rejects structural corruption" {
  let entry = {
    ..entry_for_test("historical-test", "package-test", ""),
    required_backends: ["native", "wasm"],
    required_evidence: ["contract"],
  }
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  assert_true(
    validate(registry).any(error => error.contains("requires backend-pair")),
  )
  assert_true(validate_frozen_registry(registry).is_empty())
  assert_true(
    validate_frozen_registry({ ..registry, entries: [entry, entry], }).any(error => {
      error.contains("duplicate behavior_id")
    }),
  )
  assert_true(
    validate_frozen_registry({
      ..registry,
      entries: [
        {
          ..entry,
          required_backends: ["native"],
          required_evidence: ["backend-pair"],
        },
      ],
    }).any(error => error.contains("requires native and wasm")),
  )
}
