///|
async test "release reports retain the verified oracle profile identity" {
  let root = @fs.tmpdir(prefix="mooncmd-release-profile-report-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let registry_path = root + "/archived-registry.json"
  @fs.write_file(
    registry_path, "{\"schema\":2,\"entries\":[],\"release_commands\":[],\"identity\":\"frozen\"}\n",
  )
  let registry_hash = @testkit.manifest_digest(registry_path)
  let fixture = release_case_for_test("profile-report", "echo")
  let report : CaseReport = {
    id: fixture.id,
    command: fixture.command,
    version: "0.1.5",
    category: "passed",
    detail: "",
  }
  write_report(
    root + "/report",
    [report],
    [fixture],
    true,
    Map([]),
    "",
    "",
    @async.now(),
    "sha256:verified-image",
    "verified-versions",
    oracle_profile_id="reviewed-oracle-v2",
    registry_path~,
  )
  for name in ["run-metadata.json", "summary.jsonl", "coverage.jsonl"] {
    let content = @fs.read_file(root + "/report/" + name).text()
    let value = @json.parse(content.trim().to_owned())
    match value {
      { "oracle_profile_id": String(id), .. } =>
        assert_eq(id, "reviewed-oracle-v2")
      _ => fail("report must retain the verified oracle profile ID")
    }
    assert_false(content.contains("pinned-oracle-v1"))
    match value {
      { "registry_hash": String(hash), .. }
      | { "registry_revision": String(hash), .. } =>
        assert_eq(hash, registry_hash)
      _ => fail("report must retain the selected registry identity")
    }
  }
}

///|
test "published network argv expands both fixture schemes" {
  assert_eq(
    expand_network_args(
      ["${HTTP_BASE}/fixed", "${HTTPS_BASE}/fixed", "literal"],
      Some("http://127.0.0.1:1234"),
      Some("https://127.0.0.1:4321"),
    ),
    ["http://127.0.0.1:1234/fixed", "https://127.0.0.1:4321/fixed", "literal"],
  )
  let fixture = {
    ..release_case_for_test("tls", "curl"),
    args: ["${HTTPS_BASE}/fixed.txt"],
  }
  assert_false(case_supported_on_host(fixture, "windows"))
  assert_true(case_supported_on_host(fixture, "linux"))
}

///|
test "timestamp fixtures are serialized" {
  let timestamped = {
    ..release_case_for_test("timestamped", "ls"),
    files: [
      {
        path: "input",
        content_text: Some("x"),
        content_hex: None,
        kind: None,
        target: None,
        mode: None,
        atime: Some("202001010000.00"),
        mtime: None,
      },
    ],
  }
  let ordinary = release_case_for_test("ordinary", "echo")
  assert_true(requires_serial_fixture(timestamped))
  assert_false(requires_serial_fixture(ordinary))
  assert_true(requires_serial_fixture({ ..ordinary, delay_ms: Some(5), }))
}

///|
test "release manifest version validation" {
  assert_true(valid_version("0.1.4"))
  assert_true(valid_version("12.0.7"))
  assert_false(valid_version("latest"))
  assert_false(valid_version("0.1"))
  assert_false(valid_version("0.x.1"))
}

///|
test "report directories remain unique on case-insensitive filesystems" {
  assert_true(
    report_directory_name("repair-strings-wide-B") !=
    report_directory_name("repair-strings-wide-b"),
  )
  assert_true(
    report_directory_name("repair-strings-wide-L") !=
    report_directory_name("repair-strings-wide-l"),
  )
}

///|
async test "frozen release inventory survives catalog growth but candidates remain complete" {
  let row : ReleaseCommand = {
    name: "true",
    package_name: "cli/true",
    version: "0.1.5",
    published: true,
    compare_profile: "gnu",
    supported_options: [],
    policy_sensitive: false,
  }
  let base : BaseManifest = {
    schema: 2,
    cases: [release_case_for_test("frozen-true", "true")],
  }
  let frozen : ReleaseManifest = {
    schema: 2,
    candidate: None,
    core_version: None,
    base_manifest: "active-cases.json",
    commands: [row],
    case_ids: ["frozen-true"],
    extra_cases: [],
  }
  assert_true(validate_release_manifest(frozen, base).is_empty())
  let candidate = {
    ..frozen,
    candidate: Some(true),
    commands: [{ ..row, published: false, }],
  }
  let root = workspace_root()
  assert_true(
    validate_candidate_bindings(
      root,
      candidate,
      base,
      root + "/tests/registry/registry.json",
    ).any(message => message.contains("registry release command missing")),
  )
}

///|
test "release manifest selects explicit cases" {
  let manifest : ReleaseManifest = {
    schema: 1,
    candidate: None,
    core_version: None,
    base_manifest: "tests/fixtures/runner/cases.json",
    commands: [],
    case_ids: [],
    extra_cases: [release_case_for_test("one", "echo")],
  }
  let base : BaseManifest = { schema: 1, cases: [], }
  assert_eq(selected_cases(manifest, base).length(), 1)
  assert_eq(selected_cases(manifest, base)[0].id, "one")
  assert_eq(
    selected_cases({ ..manifest, case_ids: ["one"], }, base).length(),
    1,
  )
}

///|
fn release_case_for_test(
  id : String,
  command : String,
  extra~ : String = "",
) -> ReleaseCase raise {
  @json.from_json(
    @json.parse(
      "{\"id\":\"\{id}\",\"command\":\"\{command}\",\"args\":[],\"files\":[],\"environment\":{},\"expected_status\":0,\"normalizations\":[]\{extra}}",
    ),
  )
}

///|
test "smoke availability is a pass without a semantic claim" {
  let fixture = release_case_for_test("true-status", "true")
  assert_eq(result_class("availability_passed"), "pass")
  assert_eq(verification_level(fixture, false), "availability")
  assert_eq(verification_level(fixture, true), "differential")
  assert_eq(result_class("skipped_platform"), "skip")
  assert_eq(result_class("registry_transport"), "infra")
  assert_eq(result_class("candidate_failure"), "fail")
  assert_eq(result_class("timeout"), "fail")
}

///|
test "contracts need an assertion and preserve binary exact output" {
  let weak = release_case_for_test(
    "weak",
    "sh",
    extra=",\"comparison\":\"contract\",\"forbidden_stderr\":[\"ShellError\"]",
  )
  assert_false(has_contract_assertion(weak))
  let exact = release_case_for_test(
    "binary",
    "cat",
    extra=",\"comparison\":\"contract\",\"expected_stdout_hex\":\"00ff\",\"expected_stderr_text\":\"\"",
  )
  assert_true(has_contract_assertion(exact))
  assert_eq(verification_level(exact, false), "contract")
  assert_eq(verification_level(exact, true), "contract")
  let compared = { ..exact, oracle: Some(true), }
  assert_eq(verification_level(compared, false), "contract")
  assert_eq(verification_level(compared, true), "differential")
  let empty = release_case_for_test(
    "empty",
    "true",
    extra=",\"comparison\":\"contract\",\"expected_stdout_text\":\"\",\"expected_stderr_text\":\"\"",
  )
  assert_true(has_contract_assertion(empty))
  let rejection = release_case_for_test(
    "reject",
    "cp",
    extra=",\"expected_rejection\":\"file identity unavailable\"",
  )
  assert_eq(verification_level(rejection, true), "boundary")
  assert_eq(
    verification_level({ ..rejection, oracle: Some(true), }, true),
    "boundary",
  )
}

///|
test "selection filters intersect command and case without duplicates" {
  let fixtures = [
    release_case_for_test("one", "echo"),
    release_case_for_test("two", "true"),
  ]
  assert_eq(filter_cases(fixtures, ["echo", "echo"], ["one"]).length(), 1)
  assert_eq(filter_cases(fixtures, ["echo", "true"], []).length(), 2)
  assert_true(
    (filter_cases(fixtures, ["missing"], []) catch { _ => [] }).is_empty(),
  )
  assert_true(
    (filter_cases(fixtures, [], ["missing"]) catch { _ => [] }).is_empty(),
  )
  assert_true(
    (filter_cases(fixtures, ["echo"], ["two"]) catch { _ => [] }).is_empty(),
  )
}

///|
test "candidate network diagnostics do not masquerade as registry failures" {
  assert_eq(
    failure_category({
      status: 7,
      stdout: b"",
      stderr: b"curl: failed to connect",
    }),
    "candidate_failure",
  )
  assert_eq(
    failure_category({
      status: 1,
      stdout: b"",
      stderr: b"failed to read registry asset response: timed out",
    }),
    "registry_transport",
  )
  assert_eq(
    failure_category({
      status: 255,
      stdout: b"",
      stderr: b"Prebuilt wasm asset does not exist",
    }),
    "asset_unavailable",
  )
}

///|
test "support coverage uses selected cases only" {
  let selected = release_case_for_test("selected", "echo")
  let unselected = release_case_for_test(
    "hidden",
    "echo",
    extra=",\"coverage\":[\"help\"]",
  )
  let manifest : ReleaseManifest = {
    schema: 1,
    candidate: None,
    core_version: None,
    base_manifest: "cases.json",
    commands: [
      {
        name: "echo",
        package_name: "cli/echo",
        version: "0.1.5",
        published: true,
        compare_profile: "gnu",
        supported_options: ["help"],
        policy_sensitive: false,
      },
    ],
    case_ids: ["selected"],
    extra_cases: [],
  }
  let errors = validate_release_manifest(manifest, {
    schema: 1,
    cases: [selected, unselected],
  })
  assert_true(
    errors.any(error => {
      error.contains("supported option 'help' has no coverage case")
    }),
  )
}

///|
test "report serialization preserves evidence without semantic promotion" {
  let fixture = release_case_for_test("true-status", "true")
  let observation : CaseReport = {
    id: fixture.id,
    command: fixture.command,
    version: "0.1.5",
    category: "availability_passed",
    detail: "invocation completed",
  }
  let report = shared_report(observation, [fixture], false, {
    "true-status": 12L,
  })
  assert_eq(report.result, "pass")
  assert_eq(report.verification, "availability")
  assert_eq(report.source_version, "cli/true@0.1.5")
  assert_eq(report.duration_ms, 12L)
  assert_false(report.observations.contains("stdout"))
  assert_false(report.observations.contains("stderr"))
  assert_eq(release_oracle_profile_id([observation], ""), "")
  assert_eq(
    release_oracle_profile_id([observation], "sha256:verified"),
    "pinned-oracle-v1",
  )
  assert_false(report.semantic_pass())
  observation.category = "runner_infra"
  observation.detail = "observation failed; artifacts: /tmp/fixture; cause: stat unavailable"
  let report = shared_report(observation, [fixture], true, Map([]))
  assert_eq(report.result, "infra")
  assert_eq(report.evidence, Some("/tmp/fixture"))
  assert_false(report.missing_observations.is_empty())
  assert_false(report.semantic_pass())
}

///|
test "contract output and status mismatches cannot pass" {
  let fixture = release_case_for_test(
    "bytes",
    "echo",
    extra=",\"comparison\":\"contract\",\"expected_stdout_hex\":\"00ff\",\"expected_stderr_text\":\"\"",
  )
  assert_true(
    @testkit.check_contract(
      fixture,
      { status: 0, stdout: b"\x00\xff", stderr: b"", },
      "/fixture",
    ).is_empty(),
  )
  assert_false(
    @testkit.check_contract(
      fixture,
      { status: 0, stdout: b"\x00\xfe", stderr: b"", },
      "/fixture",
    ).is_empty(),
  )
  assert_false(
    @testkit.check_contract(
      fixture,
      { status: 1, stdout: b"\x00\xff", stderr: b"", },
      "/fixture",
    ).is_empty(),
  )
}

///|
test "differential reports preserve partial diagnostics and inferred metadata" {
  let fixture = release_case_for_test(
    "diagnostic",
    "ln",
    extra=",\"comparison\":\"contract\",\"oracle\":true,\"expected_stdout_text\":\"\",\"expected_stderr_contains\":\"ln:\",\"diagnostic_reason\":\"Platform wording differs; both must identify ln.\",\"expected_files\":[{\"path\":\"file\",\"mode\":420}]",
  )
  let report = shared_report(
    {
      id: fixture.id,
      command: "ln",
      version: "0.2.1",
      category: "passed",
      detail: "candidate and pinned oracle agree",
    },
    [fixture],
    true,
    Map([]),
  )
  assert_eq(report.verification, "differential")
  assert_true(report.observations.contains("stderr-contract"))
  assert_false(report.observations.contains("stderr-bytes"))
  assert_true(report.observations.contains("mode"))
  assert_true(report.observations.contains("stdout-bytes"))
  assert_true(report.observations.contains("stdout"))
  assert_true(report.observations.contains("stderr"))
}

///|
test "availability success does not make the runner summary fail" {
  let fixture = release_case_for_test("true-status", "true")
  let (output, failures) = render_reports(
    [
      {
        id: fixture.id,
        command: fixture.command,
        version: "0.1.5",
        category: "availability_passed",
        detail: "versioned invocation completed",
      },
    ],
    [fixture],
    false,
  )
  assert_eq(failures, 0)
  assert_eq(
    output,
    "[pass/availability/availability_passed] true@0.1.5 true-status: versioned invocation completed\n" +
    "Summary: 0 semantic, 1 availability, 0 boundary, 0 skipped, 0 failed.\n",
  )
}

///|
test "runner summary counts failures without writing to the test protocol stream" {
  let fixture = release_case_for_test("true-status", "true")
  let reports = [
    "availability_passed", "semantic_mismatch", "runner_infra", "skipped_platform",
  ].map(category => {
    id: fixture.id,
    command: fixture.command,
    version: "0.1.5",
    category,
    detail: "fixture",
  })
  let (output, failures) = render_reports(reports, [fixture], false)
  assert_eq(failures, 2)
  assert_true(
    output.has_suffix(
      "Summary: 0 semantic, 1 availability, 0 boundary, 1 skipped, 2 failed.\n",
    ),
  )
}

///|
async test "oracle preflight failure retains infrastructure report with partial provenance" {
  let root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-release-preflight")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  write_oracle_preflight_failure(
    Some(directory),
    [release_case_for_test("not-started", "true")],
    root + "/tests/release_runner/current/candidate.json",
    root + "/tests/release_runner/current/active-cases.json",
    @async.now(),
    "Docker identity could not be verified",
  )
  let result = @json.parse(@fs.read_file(directory + "/summary.jsonl").text())
  match result {
    {
      "id": String(id),
      "result": String(class),
      "stage": String(stage),
      "observations": Array(observations),
      ..
    } => {
      assert_eq(id, "oracle-preflight")
      assert_eq(class, "infra")
      assert_eq(stage, "oracle_failure")
      assert_true(observations.is_empty())
    }
    _ => fail("oracle preflight summary lost infrastructure classification")
  }
  let metadata = @json.parse(
    @fs.read_file(directory + "/run-metadata.json").text(),
  )
  match metadata {
    {
      "reproducibility_status": String(status),
      "oracle_image_digest": String(digest),
      "oracle_versions_hash": String(versions),
      ..
    } => {
      assert_eq(status, "partial")
      assert_eq(digest, "")
      assert_eq(versions, "")
    }
    _ => fail("oracle preflight metadata lost missing identity fields")
  }
}

///|
async test "candidate generation follows module versions and reviewed release metadata" {
  let root = workspace_root()
  let candidate = generate_candidate_manifest(
    root,
    root + "/tests/release_runner/current/candidate.json",
    root + "/tests/registry/release-profiles.json",
    registry_path=root + "/tests/registry/registry.json",
  )
  assert_eq(candidate.candidate, Some(true))
  assert_eq(candidate.core_version, read_module_field(root, "core", "version"))
  assert_false(candidate.commands.any(row => row.name == "timeout"))
  assert_true(candidate.commands.all(row => !row.published))
  let metadata = read_release_metadata(
    root + "/tests/registry/release-profiles.json",
  )
  for row in candidate.commands {
    assert_eq(Some(row.version), read_package_version(root, row.name))
    let reviewed = metadata.commands
      .filter(item => item.name == row.name)
      .get(0)
    guard reviewed is Some(reviewed) else {
      fail("generated command lacks reviewed release metadata")
    }
    assert_eq(row.supported_options, reviewed.supported_options)
    assert_eq(row.compare_profile, reviewed.compare_profile)
  }
  let base = read_base_manifest(
    root + "/tests/release_runner/current/active-cases.json",
  )
  assert_true(validate_release_manifest(candidate, base).is_empty())
}

///|
async test "active case compatibility index is generated from registry without frozen overrides" {
  let root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-active-case-index")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let output = directory + "/active-cases.json"
  let registry_path = root + "/tests/registry/registry.json"
  write_active_cases_index(registry_path, output)
  let source = @json.parse(@fs.read_file(output).text())
  match source {
    { "case_overrides": Array(overrides), .. } =>
      assert_true(overrides.is_empty())
    _ => fail("generated case index lacks case_overrides")
  }
  let base = read_base_manifest(output)
  let registry = @registry.load(registry_path)
  assert_true(
    @registry.validate_case_bindings(
      registry,
      base.cases.map(fixture => fixture.id),
    ).is_empty(),
  )
}

///|
test "active case generation rejects unexpected source paths" {
  assert_eq(current_case_path("../cases/echo.json"), "../../cases/echo.json")
  assert_true(
    (current_case_path("../cases/../echo.json") catch { _ => "" }) == "",
  )
  assert_true((current_case_path("/tmp/echo.json") catch { _ => "" }) == "")
}

///|
async test "module coordinate parsing rejects duplicate and malformed assignments" {
  let root = @fs.tmpdir(prefix="mooncmd-module-identity")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/commands/example", recursive=true)
  let path = root + "/commands/example/moon.mod"
  @fs.write_file(path, "name = \"cli/example\"\nversion = \"1.2.3\"\n")
  assert_eq(read_package_version(root, "example"), Some("1.2.3"))
  @fs.write_file(path, "version = \"1.2.3\"\nversion = \"9.9.9\"\n")
  assert_eq(read_package_version(root, "example"), None)
  @fs.write_file(path, "version = 1.2.3\n")
  assert_eq(read_package_version(root, "example"), None)
}

///|
async test "candidate writer validates generated output corpus and ignores template base location" {
  let root = workspace_root()
  let temporary = @fs.tmpdir(prefix="mooncmd-candidate-output")
  defer (@fs.rmdir(temporary, recursive=true) catch { _ => () })
  let registry_path = root + "/tests/registry/registry.json"
  let template = read_release_manifest(
    root + "/tests/release_runner/current/candidate.json",
  )
  let misplaced = {
    ..template,
    base_manifest: "missing-historical-corpus.json",
  }
  let template_path = temporary + "/template.json"
  @fs.write_file(template_path, ToJson::to_json(misplaced).stringify())
  let active_path = temporary + "/generated-cases.json"
  write_active_cases_index(registry_path, active_path, root~)
  let output = temporary + "/candidate.json"
  write_candidate_manifest(
    root,
    template_path,
    registry_path,
    output,
    registry_path~,
    active_path~,
  )
  let candidate = read_release_manifest(output)
  assert_eq(candidate.base_manifest, "generated-cases.json")
  let base = read_base_manifest(active_path)
  assert_true(
    validate_candidate_bindings(root, candidate, base, registry_path).is_empty(),
  )
  let registry = @registry.load(registry_path)
  let reviewed = {
    ..registry,
    release_commands: registry.release_commands.map(row => {
      if row.name == "base32" {
        { ..row, releasable: false, case_ids: Some([]), }
      } else {
        row
      }
    }),
  }
  let reviewed_path = temporary + "/reviewed-registry.json"
  @fs.write_file(reviewed_path, reviewed.to_json().stringify())
  let restricted = generate_candidate_manifest(
    root,
    template_path,
    reviewed_path,
    registry_path=reviewed_path,
  )
  assert_false(restricted.commands.any(row => row.name == "base32"))
  assert_true(
    validate_candidate_bindings(root, restricted, base, reviewed_path).is_empty(),
  )
  @fs.write_file(
    template_path,
    ToJson::to_json({ ..template, candidate: Some(false), }).stringify(),
  )
  let rejected = try
    generate_candidate_manifest(
      root,
      template_path,
      registry_path,
      registry_path~,
    )
  catch {
    _ => None
  } noraise {
    _ => Some(true)
  }
  assert_eq(rejected, None)
}
