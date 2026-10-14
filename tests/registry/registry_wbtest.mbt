///|
fn entry_for_test(
  id : String,
  implementation : String,
  case_id : String,
) -> RegistryEntry {
  {
    behavior_id: id,
    command: if case_id == "" {
      ""
    } else {
      "echo"
    },
    owner: "tests/registry",
    surface: [],
    status: "supported",
    implementation,
    source: if implementation == "json-case" {
      "../cases/echo.json"
    } else {
      "tests/registry/registry.mbt::fixture"
    },
    case_id,
    aliases: [],
    coverage: [],
    required_backends: if implementation == "json-case" {
      ["native", "wasm"]
    } else {
      ["native"]
    },
    platforms: [],
    required_evidence: if implementation == "json-case" {
      ["contract", "backend-pair"]
    } else {
      ["contract"]
    },
    observations: ["status"],
    oracle_profile: "",
  }
}

///|
test "registry rejects duplicate behavior IDs" {
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [
      entry_for_test("duplicate", "package-test", ""),
      entry_for_test("duplicate", "metadata-probe", ""),
    ],
  }
  assert_true(
    validate(registry).any(item => item.contains("duplicate behavior_id")),
  )
}

///|
test "registry catches orphan and unregistered case bindings" {
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry_for_test("case:known", "json-case", "known")],
  }
  let failures = validate_case_bindings(registry, ["known", "missing"])
  assert_true(
    failures.any(item => item.contains("unregistered JSON case 'missing'")),
  )
  let orphan = validate_case_bindings(registry, ["other"])
  assert_true(
    orphan.any(item => item.contains("orphan JSON case binding 'known'")),
  )
}

///|
test "registry accepts a complete JSON case binding" {
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry_for_test("case:known", "json-case", "known")],
  }
  assert_true(validate(registry).is_empty())
  assert_true(validate_case_bindings(registry, ["known"]).is_empty())
  assert_true(
    registry.entries[0].binding()
    is JsonCase(file="../cases/echo.json", case_id="known"),
  )
}

///|
async test "registry loader round trips the machine-readable schema" {
  ignore(@async.now())
  let root = @fs.tmpdir(prefix="mooncmd-registry")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry_for_test("package-test:registry", "package-test", "")],
  }
  @fs.write_file(root + "/registry.json", registry.to_json().stringify())
  let loaded = load(root + "/registry.json")
  assert_eq(loaded.schema, 2)
  assert_eq(loaded.entries.length(), 1)
  assert_eq(loaded.entries[0].behavior_id, "package-test:registry")
  assert_true(validate(loaded).is_empty())
}

///|
async test "checked-in registry has no intrinsic validation failures" {
  let path = if @fs.exists("tests/registry/registry.json") {
    "tests/registry/registry.json"
  } else if @fs.exists("registry/registry.json") {
    "registry/registry.json"
  } else {
    "../../tests/registry/registry.json"
  }
  guard @fs.exists(path) else { fail("checked-in registry is missing") }
  let registry = load(path)
  let failures = validate(registry)
  if !failures.is_empty() {
    fail("checked-in registry is invalid: " + failures.join("; "))
  }
}

///|
test "source declarations preserve escaped stable test names" {
  assert_eq(
    test_name("async test \"pipe \\\"child\\\" lifetime\" {"),
    Some("pipe \"child\" lifetime"),
  )
  assert_eq(test_name("fn ordinary_function() -> Unit {"), None)
}

///|
test "registry source comparison rejects both orphan directions" {
  let failures : Array[String] = []
  compare_references(["new"], ["removed"], "package test", failures)
  assert_eq(failures.length(), 2)
  assert_true(failures[0].contains("unregistered"))
  assert_true(failures[1].contains("orphan"))
}

///|
test "cohort discovery includes multiline and policy declarations" {
  let source =
    #|let specs : Array[(String, String, Array[String])] = [
    #|  ("one", "compat", ["echo"]),
    #|  (
    #|    "two",
    #|    "stress",
    #|    ["cat"],
    #|  ),
    #|  ("policy-host", "policy", all),
    #|]
  assert_eq(cohort_ids(source), ["one", "two", "policy-host"])
  let dispatch =
    #|let display = "not-dispatched"
    #|match fixture.id {
    #|  "one" => execute_one()
    #|  "two" =>
    #|    execute_two()
    #|  _ => fail("unknown scenario")
    #|}
  assert_eq(dispatch_ids(dispatch), ["one", "two"])
}

///|
async test "checked-in registry binds all executable test sources" {
  let root = if @fs.exists("tests/registry/registry.json") {
    ""
  } else if @fs.exists("registry/registry.json") {
    "../"
  } else {
    "../../"
  }
  let registry = load(root + "tests/registry/registry.json")
  let failures = validate_source_bindings(registry, root~)
  guard failures.is_empty() else { fail(failures.join("\n")) }
}

///|
test "typed evidence IDs preserve source identity and category" {
  let scenario = {
    ..entry_for_test("stable-scenario", "stateful-scenario", ""),
    source: "tests/runner/scenarios.mbt::same-name",
  }
  let cohort = {
    ..scenario,
    behavior_id: "stable-cohort",
    implementation: "compatibility-cohort",
    source: "tests/runner/cohorts.mbt::same-name",
  }
  assert_true(scenario.evidence_ids().contains("scenario:same-name"))
  assert_false(scenario.evidence_ids().contains("same-name"))
  assert_false(cohort.evidence_ids().contains("scenario:same-name"))
  assert_true(cohort.evidence_ids().contains("cohort:same-name"))
  let package_test = entry_for_test("stable-test", "package-test", "")
  assert_true(
    package_test
    .evidence_ids()
    .contains("package-test:tests/registry/registry.mbt::fixture"),
  )
  assert_false(package_test.evidence_ids().contains("fixture"))
}

///|
test "registry rejects duplicate bindings and empty coverage dimensions" {
  let entry = entry_for_test("test-one", "package-test", "")
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [
      entry,
      {
        ..entry,
        behavior_id: "test-two",
        required_backends: [],
        required_evidence: [],
        observations: [],
        platforms: ["darwin"],
      },
    ],
  }
  let failures = validate(registry)
  for
    message in [
      "duplicate executable binding", "at least one backend", "at least one evidence",
      "at least one observation", "unsupported platform",
    ] {
    assert_true(failures.any(item => item.contains(message)))
  }
}

///|
test "case binding rejects moved source command and platform drift" {
  let registry : Registry = {
    schema: 2,
    release_commands: [],
    entries: [entry_for_test("case:known", "json-case", "known")],
  }
  let failures = validate_case_source(registry, "tests/cases/echo.json", [
    { "id": "known", "command": "cat", "host_platforms": ["posix"] },
  ])
  assert_true(failures.any(item => item.contains("source or command mismatch")))
  assert_true(
    failures.any(item => item.contains("platform exception mismatch")),
  )
}

///|
test "lifecycle references must bind discovered registered tests" {
  let entry = entry_for_test("test-one", "package-test", "")
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let proven : LifecycleCase = {
    id: "retention",
    status: "proven",
    test_ref: entry.source,
    proves: ["retains-bytes"],
    limitations: [],
  }
  assert_true(
    validate_lifecycle_bindings({ schema: 1, cases: [proven], }, registry, [
      entry.source,
    ]).is_empty(),
  )
  let failures = validate_lifecycle_bindings(
    {
      schema: 1,
      cases: [
        { ..proven, test_ref: "tests/missing.mbt::removed", },
        { ..proven, status: "deferred", test_ref: "", },
      ],
    },
    registry,
    [entry.source],
  )
  for
    message in [
      "orphan test reference", "not registered", "duplicate ID", "requires a limitation",
    ] {
    assert_true(failures.any(item => item.contains(message)))
  }
}

///|
test "package backend defaults and platform exceptions remain explicit" {
  assert_eq(package_backends("import { }"), ["native", "wasm"])
  assert_eq(package_backends("supported_targets = \"native\""), ["native"])
  assert_eq(package_backends("supported_targets = \"wasm\""), ["wasm"])
  let entry = entry_for_test("test-one", "package-test", "")
  let registry : Registry = {
    schema: 2,
    entries: [entry],
    release_commands: [],
  }
  let exceptions : PlatformExceptions = {
    schema: 1,
    exceptions: [
      {
        source: entry.source,
        platforms: ["posix"],
        reason: "requires POSIX observer",
      },
    ],
  }
  assert_true(
    validate_platform_exceptions(exceptions, registry, [entry.source]).any(item => {
      item.contains("platform exception mismatch")
    }),
  )
}
