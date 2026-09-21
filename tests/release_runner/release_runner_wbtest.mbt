///|
test "release manifest version validation" {
  assert_true(valid_version("0.1.4"))
  assert_true(valid_version("12.0.7"))
  assert_false(valid_version("latest"))
  assert_false(valid_version("0.1"))
  assert_false(valid_version("0.x.1"))
}

///|
test "release manifest selects explicit cases" {
  let manifest : ReleaseManifest = {
    schema: 1,
    candidate: None,
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
  extra? : String = "",
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
async test "availability success does not make the runner summary fail" {
  let fixture = release_case_for_test("true-status", "true")
  print_reports(
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
}
