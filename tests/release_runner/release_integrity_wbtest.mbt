///|
fn integrity_candidate(fixture : ReleaseCase) -> ReleaseManifest {
  {
    schema: 2,
    candidate: Some(true),
    release_scope: None,
    core_version: Some("0.5.0"),
    base_manifest: "cases.json",
    case_ids: [fixture.id],
    extra_cases: [],
    commands: [
      {
        name: "true",
        package_name: "cli/true",
        version: "0.2.0",
        published: false,
        compare_profile: "gnu",
        supported_options: [],
        policy_sensitive: false,
      },
    ],
  }
}

///|
test "freeze smoke requires selected fixture identity and smoke verification" {
  let fixture = release_case_for_test("selected-smoke", "true")
  let run = freeze_run_for_test()
  let result : FreezeResult = {
    id: fixture.id,
    command: fixture.command,
    result: "pass",
    verification: "availability",
    backend: "published-wasm",
    source_version: "cli/true@0.2.0",
    run_id: run.run_id,
    observations: ["status"],
    missing_observations: [],
  }
  assert_true(freeze_smoke_covered("true", [fixture], [(result, run)]))
  assert_false(
    freeze_smoke_covered("true", [fixture], [
      ({ ..result, id: "unselected", }, run),
    ]),
  )
  assert_false(
    freeze_smoke_covered("true", [fixture], [
      ({ ..result, verification: "differential", }, run),
    ]),
  )
  assert_false(
    freeze_smoke_covered("true", [fixture], [
      ({ ..result, observations: [], }, run),
    ]),
  )
}

///|
async test "freeze report collection rejects missing metadata despite complete label" {
  let root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-freeze-report")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  @fs.mkdir(directory + "/run")
  let fixture = release_case_for_test("selected-contract", "true")
  let candidate = integrity_candidate(fixture)
  let run = freeze_run_for_test()
  let evidence : FreezeEvidence = {
    schema: 1,
    candidate_hash: run.manifest_hash,
    git_revision: run.git_revision,
    registry: [],
    smoke_report_dirs: ["run"],
    semantic_report_dirs: ["run"],
  }
  let summary : Json = {
    "id": Json(fixture.id),
    "command": "true",
    "result": "pass",
    "verification": "contract",
    "backend": "published-wasm",
    "source_version": "cli/true@0.2.0",
    "run_id": Json(run.run_id),
    "observations": ["status", "stdout", "stderr"],
    "missing_observations": [],
  }
  @fs.write_file(directory + "/run/summary.jsonl", summary.stringify() + "\n")
  let profile = @testkit.read_oracle_profile(
    root + "/tests/runner/image/profile.json",
  )
  @fs.write_file(
    directory + "/run/run-metadata.json",
    ToJson::to_json(run).stringify(),
  )
  let accepted = collect_freeze_results(
    ["run"],
    directory,
    evidence,
    candidate,
    run.registry_hash,
    run.case_corpus_hash,
    profile,
  )
  assert_eq(accepted.length(), 1)
  for
    invalid in [
      ToJson::to_json({ ..run, toolchain: "", }),
      ToJson::to_json({ ..run, wasm_artifact_hash: "", }),
      ToJson::to_json({ ..run, environment_fingerprint: "", }),
      ToJson::to_json({
        ..run,
        execution_environments: [],
        environment_fingerprint: @testkit.execution_environment_digest([]),
      }),
      ToJson::to_json({ ..run, ended_at_ms: 0L, }),
      { "run_id": Json(run.run_id), "reproducibility_status": "complete" },
    ] {
    @fs.write_file(directory + "/run/run-metadata.json", invalid.stringify())
    let rejected = try {
      ignore(
        collect_freeze_results(
          ["run"],
          directory,
          evidence,
          candidate,
          run.registry_hash,
          run.case_corpus_hash,
          profile,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "candidate version validation checks core and module identity" {
  let root = @fs.tmpdir(prefix="mooncmd-core-coordinate")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/core")
  @fs.mkdir(root + "/commands/true", recursive=true)
  @fs.write_file(
    root + "/core/moon.mod",
    "name = \"cli/core\"\nversion = \"0.5.0\"\n",
  )
  @fs.write_file(
    root + "/commands/true/moon.mod",
    "name = \"cli/true\"\nversion = \"0.2.0\"\n",
  )
  let candidate = integrity_candidate(release_case_for_test("true", "true"))
  assert_true(validate_package_versions(root, candidate).is_empty())
  for version in [None, Some("0.4.0")] {
    assert_false(
      validate_package_versions(root, { ..candidate, core_version: version, }).is_empty(),
    )
  }
  @fs.write_file(
    root + "/core/moon.mod",
    "name = \"other/core\"\nversion = \"0.5.0\"\n",
  )
  assert_false(validate_package_versions(root, candidate).is_empty())
  @fs.write_file(
    root + "/core/moon.mod",
    "name = \"cli/core\"\nversion = \"0.5.0\"\n",
  )
  @fs.write_file(
    root + "/commands/true/moon.mod",
    "name = \"other/true\"\nversion = \"0.2.0\"\n",
  )
  assert_false(validate_package_versions(root, candidate).is_empty())
}

///|
async test "immutable snapshot resolver follows nested indexes and rejects reference cycles" {
  let original = release_case_for_test("nested", "true")
  let replacement = { ..original, expected_stdout_text: Some("frozen"), }
  let documents : Map[String, Bytes] = {
    "tests/index.json": @utf8.encode(
      (
        {
          "schema": 2,
          "cases": [],
          "case_files": ["nested/index.json"],
          "case_overrides": ["overrides/index.json"],
        } : Json).stringify(),
    ),
    "tests/nested/index.json": @utf8.encode(
      ({ "schema": 2, "cases": [], "case_files": ["leaf.json"] } : Json).stringify(),
    ),
    "tests/nested/leaf.json": snapshot_corpus_bytes([original]),
    "tests/overrides/index.json": @utf8.encode(
      ({ "schema": 2, "cases": [], "case_files": ["leaf.json"] } : Json).stringify(),
    ),
    "tests/overrides/leaf.json": snapshot_corpus_bytes([replacement]),
  }
  let sources : Array[(String, Bytes)] = []
  let resolved = snapshot_cases_with("tests/index.json", sources, [], path => {
    guard documents.get(path) is Some(bytes) else {
      fail("unknown snapshot input")
    }
    bytes
  })
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].expected_stdout_text, Some("frozen"))
  assert_eq(sources.length(), 5)
  documents["tests/nested/leaf.json"] = @utf8.encode(
    ({ "schema": 2, "cases": [], "case_files": ["../index.json"] } : Json).stringify(),
  )
  let rejected = try {
    ignore(
      snapshot_cases_with("tests/index.json", [], [], path => documents[path]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
async test "cold exact assets resolve before fingerprints and cached assets skip warmup" {
  let directory = @fs.tmpdir(prefix="mooncmd-asset-preflight")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let row = lifecycle_release_command()
  let cached = Ref(false)
  let calls : Array[CandidateInvocation] = []
  let digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  prepare_release_assets(
    [row],
    "injected-moonx",
    500,
    directory,
    candidate_executor=invocation => {
      calls.push(invocation)
      cached.val = true
      {
        output: { status: 0, stdout: b"Usage: echo\n", stderr: b"", },
        timed_out: false,
        cleanup_error: None,
      }
    },
    asset_digest=coordinates => {
      assert_eq(coordinates.to_owned(), ["cli/echo@0.1.5"])
      if cached.val {
        digest
      } else {
        ""
      }
    },
  )
  assert_eq(calls.length(), 1)
  assert_eq(calls[0].args, ["cli/echo@0.1.5", "--", "--help"])
  assert_eq(calls[0].stdin, b"")
  assert_eq(calls[0].environment.get("LC_ALL"), Some("C"))
  assert_eq(calls[0].environment.get("TZ"), Some("UTC"))
  let retained = @json.parse(
    @fs.read_file(directory + "/asset-preflight/echo/result.json").text(),
  )
  assert_true(
    retained
    is { "verification": String("availability"), "status": Number(0, ..), .. },
  )
  prepare_release_assets(
    [row],
    "injected-moonx",
    500,
    directory,
    candidate_executor=_ => fail("cached asset must not be invoked"),
    asset_digest=_ => digest,
  )
}

///|
async test "cold historical assets resolve even when help is rejected" {
  let directory = @fs.tmpdir(prefix="mooncmd-historical-asset-preflight")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let row = {
    ..lifecycle_release_command(),
    name: "sh",
    package_name: "cli/sh",
    version: "0.2.0",
    compare_profile: "posix",
    supported_options: ["command", "stdin-script"],
  }
  let cached = Ref(false)
  let digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  prepare_release_assets(
    [row],
    "injected-moonx",
    500,
    directory,
    candidate_executor=invocation => {
      assert_eq(invocation.args, ["cli/sh@0.2.0", "--", "--help"])
      cached.val = true
      {
        output: {
          status: 2,
          stdout: b"",
          stderr: b"sh: unsupported option --help\n",
        },
        timed_out: false,
        cleanup_error: None,
      }
    },
    asset_digest=coordinates => {
      assert_eq(coordinates.to_owned(), ["cli/sh@0.2.0"])
      if cached.val {
        digest
      } else {
        ""
      }
    },
  )
  let evidence = directory + "/asset-preflight/sh"
  let retained = @json.parse(@fs.read_file(evidence + "/result.json").text())
  assert_true(
    retained
    is {
      "purpose": String("asset-resolution"),
      "status": Number(2, ..),
      "timed_out": False,
      ..
    },
  )
  assert_eq(
    @fs.read_file(evidence + "/stderr").binary(),
    b"sh: unsupported option --help\n",
  )
  assert_false(@fs.exists(directory + "/summary.jsonl"))
  let selected = {
    ..release_case_for_test("strict-selected-contract", "sh"),
    comparison: Some("contract"),
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
  }
  assert_false(
    @testkit.check_contract(
      selected,
      { status: 2, stdout: b"", stderr: b"sh: unsupported option --help\n", },
      directory,
    ).is_empty(),
  )
}

///|
async test "asset preflight failure retains partial streams as infrastructure evidence" {
  let directory = @fs.tmpdir(prefix="mooncmd-asset-preflight-failure")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  for
    (name, timed_out, cleanup_error, resolved) in [
      ("missing", false, None, false),
      ("timeout-after-download", true, None, true),
      ("cleanup-after-download", false, Some("wait failed"), true),
    ] {
    let reports : Array[CaseReport] = []
    let invoked = Ref(false)
    retain_release_execution_failure(reports, () => {
      prepare_release_assets(
        [lifecycle_release_command()],
        "injected-moonx",
        500,
        directory + "/" + name,
        candidate_executor=_ => {
          invoked.val = true
          {
            output: {
              status: 2,
              stdout: b"partial\xff",
              stderr: b"resolution diagnostic",
            },
            timed_out,
            cleanup_error,
          }
        },
        asset_digest=_ => {
          if invoked.val && resolved {
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
          } else {
            ""
          }
        },
      )
    })
    assert_eq(reports.length(), 1)
    assert_eq(reports[0].category, "runner_infra")
    assert_true(
      reports[0].detail.contains(
        if resolved {
          "confirmed cleanup"
        } else {
          "exact cached Wasm bytes"
        },
      ),
    )
    let result = shared_report(reports[0], [], false, Map([]))
    assert_eq(result.verification, "availability")
    assert_false(result.semantic_pass())
    guard result.evidence is Some(evidence) else {
      fail("asset preflight evidence missing")
    }
    assert_eq(@fs.read_file(evidence + "/stdout").binary(), b"partial\xff")
    assert_eq(
      @fs.read_file(evidence + "/stderr").binary(),
      b"resolution diagnostic",
    )
    let retained = @json.parse(@fs.read_file(evidence + "/result.json").text())
    guard retained
      is {
        "status": Number(2, ..),
        "timed_out": actual_timeout,
        "cleanup_error": actual_cleanup,
        ..
      } else {
      fail("asset resolution receipt lost failure state")
    }
    assert_eq(actual_timeout, Json(timed_out))
    assert_eq(actual_cleanup, ToJson::to_json(cleanup_error))
  }
}

///|
async test "release validation failure writes partial metadata without semantic evidence" {
  let directory = @fs.tmpdir(prefix="mooncmd-release-validation-report")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let registry_path = directory + "/registry.json"
  @fs.write_file(
    registry_path, "{\"schema\":2,\"entries\":[],\"release_commands\":[]}\n",
  )
  write_release_preflight_failure(
    Some(directory + "/report"),
    directory + "/missing-manifest.json",
    directory + "/missing-corpus.json",
    registry_path,
    @async.now(),
    "release source could not be read",
  )
  let metadata : @testkit.RunMetadata = @json.from_json(
    @json.parse(@fs.read_file(directory + "/report/run-metadata.json").text()),
  )
  assert_eq(metadata.manifest_hash, "")
  assert_eq(metadata.case_corpus_hash, "")
  assert_eq(metadata.registry_hash, @testkit.manifest_digest(registry_path))
  assert_eq(metadata.reproducibility_status, "partial")
  let summary = @json.parse(
    @fs.read_file(directory + "/report/summary.jsonl").text(),
  )
  assert_true(
    summary
    is {
      "result": String("infra"),
      "stage": String("runner_infra"),
      "verification": String("availability"),
      "observations": Array([]),
      ..
    },
  )
  assert_eq(
    @fs.read_file(directory + "/report/coverage.jsonl").text().trim(),
    "",
  )
}
