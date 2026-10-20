///|
fn network_manifest_for_test() -> ReleaseManifest {
  {
    schema: 2,
    candidate: Some(true),
    release_scope: Some(["curl", "wget"]),
    core_version: Some("0.7.0"),
    base_manifest: "unused.json",
    commands: ["curl", "wget"].map(name => {
      name,
      package_name: "cli/" + name,
      version: "0.2.3",
      published: false,
      compare_profile: "gnu",
      supported_options: [],
      policy_sensitive: true,
    }),
    case_ids: [],
    extra_cases: [],
  }
}

///|
async test "published network executor preserves exact coordinates input and launch receipts" {
  let directory = @fs.tmpdir(prefix="mooncmd-published-network-")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let calls : Array[CandidateInvocation] = []
  let executor = published_network_executor(
    network_manifest_for_test(),
    "selected-moonx",
    731,
    directory,
    candidate_executor=invocation => {
      assert_true(
        @fs.exists(
          directory + "/invocation-" + calls.length().to_string() + ".json",
        ),
      )
      calls.push(invocation)
      {
        output: { status: 0, stdout: b"\x00\xff", stderr: b"", },
        timed_out: false,
        cleanup_error: None,
      }
    },
  )
  for command in ["curl", "wget"] {
    let result = (executor.invoke)({
      command,
      args: ["--", "literal"],
      stdin: b"\x00\xff",
      cwd: directory,
      environment: { "NO_PROXY": "*", "SCENARIO_SENTINEL": "retained" },
    })
    assert_eq(result.source_version, "cli/" + command + "@0.2.3")
    assert_eq(result.args, [result.source_version, "--", "--", "literal"])
    assert_true(result.retain_identity)
    assert_eq(result.infrastructure_error, None)
    assert_eq(result.run.output.stdout, b"\x00\xff")
  }
  assert_eq(calls.length(), 2)
  for index, invocation in calls {
    assert_eq(invocation.program, "selected-moonx")
    assert_eq(invocation.timeout_ms, 731)
    assert_eq(invocation.stdin, b"\x00\xff")
    assert_eq(invocation.cwd, directory)
    assert_eq(invocation.environment.get("SCENARIO_SENTINEL"), Some("retained"))
    assert_eq(invocation.environment.get("LC_ALL"), Some("C"))
    assert_eq(invocation.environment.get("TZ"), Some("UTC"))
    let receipt = @fs.read_file(
      directory + "/invocation-" + index.to_string() + ".json",
    ).text()
    assert_true(receipt.contains(invocation.args[0]))
    assert_true(receipt.contains(@testkit.sha256_bytes(b"\x00\xff")))
  }
  let excluded = published_network_executor(
    { ..network_manifest_for_test(), release_scope: Some(["curl"]), },
    "selected-moonx",
    731,
    directory,
    candidate_executor=_ => fail("excluded command must not launch"),
  )
  let error = try {
    ignore(
      (excluded.invoke)({
        command: "wget",
        args: [],
        stdin: b"",
        cwd: directory,
        environment: Map([]),
      }),
    )
    ""
  } catch {
    error => error.to_string()
  }
  assert_true(error.contains("outside release scope"))
}

///|
test "published network scenarios distinguish shared contracts from sealed differentials" {
  for
    id in [
      "network-auth-cookie", "network-auth-cookie-oracle", "network-transfer-boundaries",
      "network-transfer-boundaries-oracle",
    ] {
    let fixture = {
      ..release_case_for_test(id, "curl"),
      comparison: Some(
        if id.has_suffix("-oracle") {
          "oracle-scenario"
        } else {
          "scenario"
        },
      ),
      related_commands: Some(["wget"]),
    }
    assert_eq(network_scenario_commands(fixture), ["curl", "wget"])
    assert_true(requires_serial_fixture(fixture))
    let report : CaseReport = {
      id,
      command: "curl",
      version: "0.2.3",
      category: "passed",
      detail: "shared assertions; artifacts: /evidence",
    }
    let smoke = shared_report(report, [fixture], false, Map([]))
    assert_eq(smoke.backend, "published-wasm")
    assert_eq(smoke.source_version, "cli/curl@0.2.3")
    assert_eq(smoke.verification, "contract")
    assert_true(smoke.observations.contains("stdout-bytes"))
    assert_true(smoke.observations.contains("stderr-bytes"))
    let oracle = shared_report(report, [fixture], true, Map([]))
    assert_eq(
      oracle.verification,
      if id.has_suffix("-oracle") {
        "differential"
      } else {
        "contract"
      },
    )
    let failed = shared_report(
      { ..report, category: "timeout", },
      [fixture],
      true,
      Map([]),
    )
    assert_eq(failed.result, "fail")
    assert_true(failed.observations.is_empty())
    assert_false(failed.semantic_pass())
  }
}
