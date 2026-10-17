///|
async fn fixture_git(args : Array[String]) -> String {
  let root = @env.current_dir().unwrap()
  let result = @shell.Cmd(
    "git",
    [
      "-c",
      "user.name=Coverage Fixture",
      "-c",
      "user.email=coverage-fixture@example.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.autocrlf=false",
      "-c",
      "core.hooksPath=" + root + "/empty-hooks",
      "-c",
      "init.templateDir=" + root + "/empty-hooks",
      ..args,
    ],
  ).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("fixture git failed: " + result.stderr())
  }
  result.stdout().trim().to_owned()
}

///|
async fn audit_fixture_at_current_directory(executable : String) -> Unit {
  for
    directory in [
      "core", "commands/echo", "tests/cases", "tests/registry", "tests/runner", "docs/reports/history",
    ] {
    @fs.mkdir(directory, recursive=true, allow_exist=true)
  }
  @fs.write_file(".gitignore", "/reports/\nempty-hooks/\nempty-gitconfig\n")
  @fs.write_file("docs/reports/README.md", "# Reports\n")
  @fs.write_file("docs/reports/history/README.md", "# Recorded result\n")
  @fs.write_file("tests/runner/cohorts.mbt", "")
  @fs.write_file("tests/runner/scenarios.mbt", "")
  @fs.write_file(
    "tests/registry/platform-exceptions.json", "{\"schema\":1,\"exceptions\":[]}",
  )
  // Preserve the production completeness schema in this synthetic audit fixture.
  // Rebound names prove only the audit protocol, not harness lifecycle behavior.
  let lifecycle = @json.parse(@fs.read_file("lifecycle-template.json").text())
  guard lifecycle is Object(lifecycle_fields) &&
    lifecycle_fields.get("cases") is Some(Array(lifecycle_cases)) else {
    fail("invalid lifecycle protocol template")
  }
  let anchor = "tests/registry/lifecycle_fixture_wbtest.mbt::protocol lifecycle anchor"
  for item in lifecycle_cases {
    guard item is Object(fields) else { fail("invalid lifecycle protocol row") }
    if fields.get("status") == Some(Json::string("proven")) {
      fields["test_ref"] = Json::string(anchor)
    }
  }
  @fs.write_file(
    "tests/registry/lifecycle.json",
    @testkit.canonical_json(lifecycle),
  )
  @fs.write_file(
    "tests/registry/lifecycle_fixture_wbtest.mbt", "///|\ntest \"protocol lifecycle anchor\" {\n  assert_true(true)\n}\n",
  )
  @fs.write_file("tests/registry/moon.pkg", "supported_targets = \"native\"\n")
  let corpus : Json = {
    "schema": 2,
    "cases": [
      {
        "id": "echo",
        "command": "echo",
        "args": ["fixture"],
        "files": [],
        "environment": {},
        "expected_status": 0,
        "expected_stdout_text": "fixture\n",
        "normalizations": [],
      },
    ],
  }
  @fs.write_file("tests/cases/echo.json", @testkit.canonical_json(corpus))
  let registry : @registry.Registry = {
    schema: 2,
    release_commands: [],
    entries: [
      {
        ..audit_entry(),
        aliases: [],
        required_backends: ["native"],
        required_evidence: ["contract"],
      },
      {
        ..audit_entry(),
        behavior_id: "package-test:" + anchor,
        command: "",
        owner: "tests/registry",
        implementation: "package-test",
        source: anchor,
        case_id: "",
        aliases: [],
        required_backends: ["native"],
        required_evidence: ["contract"],
        observations: ["status"],
      },
    ],
  }
  @fs.write_file(
    "tests/registry/registry.json",
    @testkit.canonical_json(ToJson::to_json(registry)),
  )
  let declaration : Json = {
    "schema": 1,
    "affected_commands": ["echo"],
    "affected_behaviors": ["case:echo"],
    "affected_options": [],
    "affected_operands": [],
    "case_ids": ["echo"],
    "published_manifest_affected": false,
    "required_backends": ["native"],
    "required_evidence": ["contract"],
    "required_observations": ["status", "stdout"],
    "coverage": [
      {
        "behavior_id": "case:echo",
        "backends": ["native"],
        "evidence": ["contract"],
        "observations": ["status", "stdout"],
        "result": "pass",
        "report": "reports/summary.jsonl",
      },
    ],
    "boundaries": [],
    "deferred": [],
  }
  @fs.write_file("change.json", @testkit.canonical_json(declaration))
  @fs.write_file(
    "commands/echo/main.mbt", "///|\nfn fixture_value() -> Int { 0 }\n",
  )
  ignore(fixture_git(["init", "--quiet"]))
  ignore(fixture_git(["add", "."]))
  ignore(fixture_git(["commit", "--quiet", "-m", "fixture base"]))
  let base = fixture_git(["rev-parse", "HEAD"])
  let head_source = "///|\nfn fixture_value() -> Int { 1 }\n"
  @fs.write_file("commands/echo/main.mbt", head_source)
  ignore(fixture_git(["add", "commands/echo/main.mbt"]))
  ignore(fixture_git(["commit", "--quiet", "-m", "fixture head"]))
  let head = fixture_git(["rev-parse", "HEAD"])
  assert_true(base != head)
  assert_eq(fixture_git(["status", "--porcelain=v1"]), "")
  let registry_path = "tests/registry/registry.json"
  let corpus_path = "tests/cases/echo.json"
  let host = @testkit.host_platform()
  let now = @async.now()
  // This is a protocol fixture, not command acceptance evidence. Its Git and
  // input fingerprints are real; descriptive runtime fields identify the fixture.
  let metadata : @testkit.RunMetadata = {
    schema: 1,
    run_id: "audit-integration",
    git_revision: head,
    git_dirty: "false",
    toolchain: "audit-integration-fixture",
    runner_version: "fixture-v1",
    registry_hash: @testkit.manifest_digest(registry_path),
    manifest_hash: @testkit.manifest_digest(corpus_path),
    case_corpus_hash: @testkit.manifest_digest(corpus_path),
    native_artifact_hash: @testkit.file_digest(executable),
    wasm_artifact_hash: "",
    oracle_profile_id: "",
    oracle_image_digest: "",
    oracle_versions_hash: "",
    moonx_coordinates: [],
    platform: host,
    os: "isolated-git-fixture",
    architecture: "fixture",
    locale: "C",
    timezone: "UTC",
    docker_version: "",
    policy_hash: @testkit.sha256_text("fixture policy"),
    environment_fingerprint: @testkit.execution_environment_digest([
      {
        program: "fixture",
        inherit_env: true,
        values: { "LC_ALL": "C", "TZ": "UTC" },
      },
    ]),
    host_environment_fingerprint: @testkit.sha256_text("fixture environment"),
    execution_environments: [
      {
        program: "fixture",
        inherit_env: true,
        values: { "LC_ALL": "C", "TZ": "UTC" },
      },
    ],
    started_at_ms: now,
    ended_at_ms: now,
    reproducibility_status: "complete",
  }
  guard metadata.native_artifact_hash != "" else {
    fail("fixture executable is unavailable")
  }
  let row : @testkit.CaseReport = {
    id: "case:echo",
    command: "echo",
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "controlled audit protocol fixture",
    platform: host,
    backend: "native",
    source_version: "workspace",
    duration_ms: 0L,
    observations: ["status", "stdout"],
    missing_observations: [],
    evidence: None,
  }
  @testkit.write_reports_with_metadata("reports", [row], metadata)
  let options : AuditOptions = {
    base,
    head,
    declaration_path: "change.json",
    run_metadata_paths: ["reports/run-metadata.json"],
    registry_path,
    case_corpus_paths: [corpus_path],
    manifest_paths: [corpus_path],
    oracle_profile_paths: [],
    report_path: None,
  }
  let clean = audit(options)
  assert_eq(clean.status, "passed", msg=clean.findings.join("\n"))
  assert_eq(clean.base, base)
  assert_eq(clean.head, head)
  assert_eq(clean.changed_paths, ["commands/echo/main.mbt"])
  assert_eq(clean.run_ids, ["audit-integration"])
  assert_true(clean.uncovered.is_empty())
  let substituted_case = {
    ..@testkit.load_cases(corpus_path)[0],
    args: ["substituted"],
    expected_stdout_text: Some("substituted\n"),
  }
  let substituted_path = "reports/substituted.json"
  @fs.write_file(
    substituted_path,
    @testkit.canonical_json({
      "schema": 2,
      "cases": [ToJson::to_json(substituted_case)],
    }),
  )
  let substituted_hash = @testkit.manifest_digest(substituted_path)
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(
      ToJson::to_json({ ..metadata, case_corpus_hash: substituted_hash, }),
    ),
  )
  // A matching supplied hash and the original stable ID cannot authorize a
  // different invocation or weaker assertions than the registered body.
  let substituted = audit({ ..options, case_corpus_paths: [substituted_path], })
  assert_eq(substituted.status, "failed")
  assert_true(
    substituted.findings.any(message => {
      message.contains("selected case body differs from registered source")
    }),
    msg=substituted.findings.join("\n"),
  )
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(
      ToJson::to_json({ ..metadata, manifest_hash: substituted_hash, }),
    ),
  )
  let substituted_manifest = audit({
    ..options,
    manifest_paths: [substituted_path],
  })
  assert_eq(substituted_manifest.status, "failed")
  assert_true(
    substituted_manifest.findings.any(message => {
      message.contains("selected case body differs from registered source")
    }),
    msg=substituted_manifest.findings.join("\n"),
  )
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(ToJson::to_json(metadata)),
  )
  @fs.write_file("commands/echo/main.mbt", head_source + "// Dirty fixture.\n")
  let dirty = audit(options)
  assert_eq(dirty.status, "failed")
  assert_true(
    dirty.findings.any(message => {
      message.contains("audit requires a clean checkout")
    }),
  )
  @fs.write_file("commands/echo/main.mbt", head_source)
  let wrong_head = audit({ ..options, head: base, })
  assert_eq(wrong_head.status, "failed")
  assert_true(
    wrong_head.findings.any(message => {
      message.contains("checked-out HEAD must equal the audited head")
    }),
  )
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(
      ToJson::to_json({ ..metadata, git_revision: base, }),
    ),
  )
  let wrong_revision = audit(options)
  assert_eq(wrong_revision.status, "failed")
  assert_true(
    wrong_revision.findings.any(message => {
      message.contains("git_revision does not match resolved head")
    }),
  )
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(ToJson::to_json({ ..metadata, git_dirty: "true", })),
  )
  let dirty_run = audit(options)
  assert_eq(dirty_run.status, "failed")
  assert_true(
    dirty_run.findings.any(message => {
      message.contains("dirty runs cannot prove the committed range")
    }),
  )
  @fs.write_file(
    "reports/run-metadata.json",
    @testkit.canonical_json(ToJson::to_json(metadata)),
  )
  let restored = audit(options)
  assert_eq(restored.status, "passed", msg=restored.findings.join("\n"))
  ci_report_history_fixture(head)
  ci_checkout_eol_fixture()
  @fs.write_file(
    "reports/fixture-complete.json",
    @testkit.canonical_json({
      "clean": Json(clean.status),
      "substituted_case": Json(substituted.status),
      "substituted_manifest": Json(substituted_manifest.status),
      "dirty_checkout": Json(dirty.status),
      "wrong_head": Json(wrong_head.status),
      "wrong_revision": Json(wrong_revision.status),
      "dirty_run": Json(dirty_run.status),
      "restored": Json(restored.status),
    }),
  )
}

///|
async fn ci_report_history_fixture(base : String) -> Unit {
  let historical = "docs/reports/history/README.md"
  let refusal = "existing historical report cannot be modified, deleted or renamed: " +
    historical
  @fs.mkdir("docs/reports/current")
  @fs.write_file("docs/reports/current/README.md", "# New result\n")
  @fs.write_file(
    "docs/reports/README.md", "# Reports\n\nNew result recorded.\n",
  )
  ignore(fixture_git(["add", "docs/reports"]))
  ignore(fixture_git(["commit", "--quiet", "-m", "new report and live index"]))
  let added = fixture_git(["rev-parse", "HEAD"])
  assert_true(ci_report_history_errors(base, added).is_empty())
  @fs.write_file(historical, "# Rewritten result\n")
  ignore(fixture_git(["add", historical]))
  ignore(fixture_git(["commit", "--quiet", "-m", "rewrite existing report"]))
  let edited = fixture_git(["rev-parse", "HEAD"])
  assert_eq(ci_report_history_errors(added, edited), [refusal])
  @fs.write_file(
    "commands/echo/main.mbt", "///|\nfn fixture_value() -> Int { 2 }\n",
  )
  ignore(fixture_git(["add", "commands/echo/main.mbt"]))
  ignore(
    fixture_git(["commit", "--quiet", "-m", "mixed code and report range"]),
  )
  let mixed = fixture_git(["rev-parse", "HEAD"])
  assert_eq(ci_report_history_errors(added, mixed), [refusal])
  ignore(fixture_git(["mv", historical, "docs/reports/history/renamed.md"]))
  ignore(fixture_git(["commit", "--quiet", "-m", "rename existing report"]))
  let renamed = fixture_git(["rev-parse", "HEAD"])
  assert_eq(ci_report_history_errors(mixed, renamed), [refusal])
  ignore(fixture_git(["rm", "docs/reports/history/renamed.md"]))
  ignore(fixture_git(["commit", "--quiet", "-m", "delete historical report"]))
  let deleted = fixture_git(["rev-parse", "HEAD"])
  assert_eq(ci_report_history_errors(added, deleted), [refusal])
  try ci_report_history_errors("missing-fixture-base", deleted) catch {
    error =>
      assert_true(
        error.to_string().contains("CI historical report lookup failed"),
      )
  } noraise {
    _ => fail("CI accepted an unavailable historical report comparison")
  }
}

///|
async fn ci_checkout_eol_fixture() -> Unit {
  let paths = [
    "eol-fixture/source.mbt", "eol-fixture/pkg.generated.mbti", "eol-fixture/script.mbtx",
    "eol-fixture/moon.pkg", "eol-fixture/moon.mod", "eol-fixture/moon.work",
  ]
  let contents = "first line\nsecond line\n"
  let json_path = "tests/eol-fixture.json"
  let json_bytes = b"{\r\n  \"fixture\": true\r\n}\r\n"
  @fs.mkdir("eol-fixture")
  for path in paths {
    @fs.write_file(path, contents)
  }
  @fs.write_file(json_path, json_bytes)
  @fs.write_file(
    ".gitattributes",
    @fs.read_file("attributes-template").binary(),
  )
  ignore(fixture_git(["config", "core.autocrlf", "true"]))
  ignore(
    fixture_git(
      ["-c", "core.autocrlf=true", "add", ".gitattributes", json_path, ..paths],
    ),
  )
  ignore(fixture_git(["commit", "--quiet", "-m", "canonical checkout fixture"]))
  for path in paths + [json_path] {
    @fs.remove(path)
  }
  // Refresh the isolated fixture's checkout and index as a fresh clone does.
  // The production CI never resets its checkout to satisfy the clean gate.
  ignore(
    fixture_git(
      [
        "-c", "core.autocrlf=true", "checkout-index", "--force", "--index", "--",
        ..paths, json_path,
      ],
    ),
  )
  for path in paths {
    assert_eq(@fs.read_file(path).text(), contents, msg=path)
  }
  assert_eq(@fs.read_file(json_path).binary(), json_bytes)
  ci_require_clean_checkout()
  for path in paths {
    @fs.write_file(path, contents)
  }
  ignore(fixture_git(["-c", "core.autocrlf=true", "diff", "--exit-code"]))
  ci_require_clean_checkout()
  @fs.write_file(paths[0], "changed content\n")
  try ci_require_clean_checkout() catch {
    error => assert_true(error.to_string().contains(" M " + paths[0]))
  } noraise {
    _ => fail("CI accepted changed tracked content")
  }
  @fs.write_file(paths[0], contents)
  @fs.write_file("untracked-ci-fixture.txt", "untracked\n")
  try ci_require_clean_checkout() catch {
    error =>
      assert_true(error.to_string().contains("?? untracked-ci-fixture.txt"))
  } noraise {
    _ => fail("CI accepted an untracked file")
  }
  @fs.remove("untracked-ci-fixture.txt")
  ci_require_clean_checkout()
}

///|
async test "coverage audit accepts a clean exact head and rejects dirty or mismatched revisions" {
  guard @env.args().get(0) is Some(program) else {
    fail("missing test executable path")
  }
  let executable = @fs.realpath(program)
  if @env.get_env_var("MOONCMD_COVERAGE_GIT_FIXTURE") is Some(root) {
    assert_eq(@fs.realpath("."), @fs.realpath(root))
    guard !@fs.exists(".git") &&
      !@fs.exists("commands") &&
      !@fs.exists("core") &&
      !@fs.exists("tests") &&
      @fs.exists("empty-hooks") else {
      fail("coverage fixture child requires its fresh temporary directory")
    }
    audit_fixture_at_current_directory(executable)
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-coverage-git-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/empty-hooks")
  @fs.write_file(root + "/empty-gitconfig", "")
  let mut lifecycle_path = ""
  for
    path in [
      "tests/registry/lifecycle.json", "registry/lifecycle.json", "../../tests/registry/lifecycle.json",
    ] {
    if @fs.exists(path) {
      lifecycle_path = path
      break
    }
  }
  guard lifecycle_path != "" else { fail("missing lifecycle fixture template") }
  @fs.write_file(
    root + "/lifecycle-template.json",
    @fs.read_file(lifecycle_path).binary(),
  )
  let attributes_path = @path.Path(@fs.realpath(lifecycle_path))
    .dirname()
    .dirname()
    .dirname()
    .join(Path(".gitattributes"))
    .to_string()
  @fs.write_file(
    root + "/attributes-template",
    @fs.read_file(attributes_path).binary(),
  )
  let environment : Map[String, String] = Map([])
  for name, value in @env.get_env_vars() {
    if !name.has_prefix("GIT_") {
      environment[name] = value
    }
  }
  environment["GIT_CONFIG_NOSYSTEM"] = "1"
  environment["GIT_CONFIG_GLOBAL"] = root + "/empty-gitconfig"
  environment["MOONCMD_COVERAGE_GIT_FIXTURE"] = root
  // Relaunch only this test, whose index is zero in its dedicated source file.
  // The native driver's observed file:index-range protocol needs no nested moon
  // build and gives audit() a process-local cwd without mutating other tests.
  let child = @shell.Cmd(
    executable,
    ["integration_wbtest.mbt:0-1"],
    cwd=root,
    env=environment,
    inherit_env=false,
  ).output(timeout_ms=60000)
  guard child.exit_code() == 0 &&
    @fs.exists(root + "/reports/fixture-complete.json") else {
    fail("isolated coverage audit failed:\n" + child.stdout() + child.stderr())
  }
  let completed = @json.parse(
    @fs.read_file(root + "/reports/fixture-complete.json").text(),
  )
  assert_eq(completed, {
    "clean": "passed",
    "substituted_case": "failed",
    "substituted_manifest": "failed",
    "dirty_checkout": "failed",
    "wrong_head": "failed",
    "wrong_revision": "failed",
    "dirty_run": "failed",
    "restored": "passed",
  })
}
