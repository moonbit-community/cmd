///|
test "canonical JSON and byte digests are stable" {
  let value = @json.parse("{\"z\":1,\"a\":{\"b\":2,\"a\":3}}")
  assert_eq(canonical_json(value), "{\"a\":{\"a\":3,\"b\":2},\"z\":1}")
  assert_eq(
    sha256_bytes(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(json_digest(value), sha256_text(canonical_json(value)))
}

///|
test "metadata completeness is recomputed and coordinates do not replace artifact bytes" {
  let digest = sha256_text("verified fixture input")
  let profiles = [
    effective_environment(
      "fixture",
      Map([]),
      { "LC_ALL": "C", "TZ": "UTC" },
      true,
    ),
  ]
  let metadata : RunMetadata = {
    schema: 1,
    run_id: "complete-fixture",
    git_revision: "1111111111111111111111111111111111111111",
    git_dirty: "false",
    toolchain: "fixture-toolchain",
    runner_version: "fixture-runner",
    registry_hash: digest,
    manifest_hash: digest,
    case_corpus_hash: digest,
    native_artifact_hash: "",
    wasm_artifact_hash: digest,
    oracle_profile_id: "",
    oracle_image_digest: "",
    oracle_versions_hash: "",
    moonx_coordinates: ["cli/true@0.1.0"],
    platform: "macos",
    os: "Darwin",
    architecture: "arm64",
    locale: "C",
    timezone: "UTC",
    docker_version: "",
    policy_hash: digest,
    environment_fingerprint: execution_environment_digest(profiles),
    host_environment_fingerprint: digest,
    execution_environments: profiles,
    started_at_ms: 1L,
    ended_at_ms: 2L,
    reproducibility_status: "complete",
  }
  assert_true(run_metadata_errors(metadata).is_empty())
  assert_true(
    run_metadata_errors({
      ..metadata,
      execution_environments: [],
      environment_fingerprint: execution_environment_digest([]),
    }).contains("missing executed environment profiles"),
  )
  let controlled = effective_environment(
    "candidate",
    Map([]),
    { "LC_ALL": "C", "TZ": "UTC" },
    true,
  )
  let finish = {
    ..metadata,
    execution_environments: [controlled],
    environment_fingerprint: execution_environment_digest([controlled]),
  }
  let completed = finalize_run_metadata(metadata, finish)
  assert_eq(completed.reproducibility_status, "complete")
  assert_eq(completed.execution_environments.length(), 1)
  assert_eq(completed.environment_fingerprint, finish.environment_fingerprint)
  assert_true(
    run_metadata_errors({
      ..finish,
      environment_fingerprint: metadata.environment_fingerprint,
    }).contains("execution environment fingerprint mismatch"),
  )
  assert_eq(
    finalize_run_metadata(metadata, {
      ..finish,
      host_environment_fingerprint: sha256_text("changed host"),
    }).reproducibility_status,
    "changed-during-run",
  )
  let changed = finalize_run_metadata(metadata, {
    ..metadata,
    wasm_artifact_hash: sha256_text("different executed bytes"),
  })
  assert_eq(changed.wasm_artifact_hash, digest)
  assert_eq(changed.reproducibility_status, "changed-during-run")
  assert_false(run_metadata_errors(changed).is_empty())
  assert_eq(
    with_oracle_versions_hash(changed, "").reproducibility_status,
    "changed-during-run",
  )
  assert_true(
    run_metadata_errors({ ..metadata, wasm_artifact_hash: "", }).contains(
      "missing executed artifact hash",
    ),
  )
  assert_true(
    run_metadata_errors({ ..metadata, policy_hash: "", }).any(error => {
      error.contains("policy_hash")
    }),
  )
  let oracle = {
    ..metadata,
    oracle_profile_id: "profile",
    oracle_image_digest: "sha256:" + digest,
    oracle_versions_hash: digest,
  }
  assert_true(run_metadata_errors(oracle).contains("missing docker_version"))
  assert_true(
    run_metadata_errors({ ..oracle, docker_version: "Docker fixture", }).is_empty(),
  )
  let identity : OracleIdentity = {
    image: "sha256:" + digest,
    digest: "sha256:" + digest,
    versions: "observed inventory\n",
    profile_id: "profile",
  }
  let bound = with_oracle_identity(
    { ..metadata, docker_version: "Docker fixture", },
    identity,
  )
  let oracle_finish = with_oracle_versions_hash(
    {
      ..finish,
      docker_version: "Docker fixture",
      oracle_profile_id: identity.profile_id,
      oracle_image_digest: identity.digest,
    },
    sha256_text(identity.versions),
  )
  let accepted = finalize_run_metadata(bound, oracle_finish)
  assert_eq(accepted.reproducibility_status, "complete")
  assert_eq(accepted.oracle_profile_id, identity.profile_id)
  assert_eq(accepted.oracle_image_digest, identity.digest)
  assert_eq(accepted.oracle_versions_hash, sha256_text(identity.versions))
  assert_true(run_metadata_errors(accepted).is_empty())
  for
    drift in [
      { ..oracle_finish, oracle_profile_id: "different-profile", },
      {
        ..oracle_finish,
        oracle_image_digest: "sha256:" + sha256_text("other"),
      },
      { ..oracle_finish, oracle_versions_hash: sha256_text("other inventory"), },
    ] {
    let rejected = finalize_run_metadata(bound, drift)
    assert_eq(rejected.reproducibility_status, "changed-during-run")
    assert_eq(rejected.oracle_image_digest, identity.digest)
    assert_false(run_metadata_errors(rejected).is_empty())
  }
  let rebound = with_oracle_identity(bound, {
    ..identity,
    digest: "sha256:" + sha256_text("other"),
  })
  assert_eq(rebound.oracle_image_digest, identity.digest)
  assert_eq(rebound.reproducibility_status, "changed-during-run")
  assert_eq(
    finalize_run_metadata(rebound, oracle_finish).reproducibility_status,
    "changed-during-run",
  )
  for
    field in [
      "toolchain", "policy_hash", "docker_version", "environment_fingerprint", "host_environment_fingerprint",
      "execution_environments", "started_at_ms", "ended_at_ms",
    ] {
    let json = ToJson::to_json(metadata)
    guard json is Object(fields) else { fail("metadata must encode as object") }
    fields.remove(field)
    let rejected = (@json.from_json(json) : RunMetadata) catch { _ => continue }
    fail("missing metadata field decoded: " + field + rejected.run_id)
  }
}

///|
async test "artifact digest includes sorted paths and bytes" {
  let root = @fs.tmpdir(prefix="mooncmd-artifact-digest-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/nested", recursive=true)
  @fs.write_file(root + "/nested/b", b"b")
  @fs.write_file(root + "/a", b"a")
  let first = artifact_digest(root)
  // Rewriting the same bytes in a different insertion order must not alter
  // the tree identity.
  @fs.remove(root + "/a")
  @fs.write_file(root + "/a", b"a")
  let second = artifact_digest(root)
  assert_eq(first, second)
  @fs.write_file(root + "/nested/b", b"changed")
  assert_true(artifact_digest(root) != first)
}

///|
async test "cyclic manifest fingerprints remain partial without recursing forever" {
  let root = @fs.tmpdir(prefix="mooncmd-cyclic-manifest")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/a.json", "{\"case_files\":[\"b.json\"]}")
  @fs.write_file(root + "/b.json", "{\"case_overrides\":[\"./a.json\"]}")
  assert_eq(manifest_digest(root + "/a.json"), "")
  @fs.write_file(root + "/b.json", "{\"cases\":[]}")
  assert_true(valid_sha256(manifest_digest(root + "/a.json")))
}

///|
async test "run metadata enriches every report and preserves aggregation" {
  let root = @fs.tmpdir(prefix="mooncmd-report-metadata-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let metadata = collect_run_metadata("run-wbtest")
  let reports : Array[CaseReport] = [
    {
      id: "first",
      command: "true",
      result: "pass",
      verification: "contract",
      stage: "complete",
      detail: "",
      platform: host_platform(),
      backend: "native",
      source_version: "workspace",
      duration_ms: 1L,
      observations: ["status"],
      missing_observations: [],
      evidence: None,
    },
    {
      id: "second",
      command: "false",
      result: "infra",
      verification: "contract",
      stage: "cleanup",
      detail: "cleanup failed",
      platform: host_platform(),
      backend: "native",
      source_version: "workspace",
      duration_ms: 2L,
      observations: [],
      missing_observations: ["status"],
      evidence: Some(root + "/second"),
    },
  ]
  write_reports_with_metadata(root, reports, metadata)
  let summary = @fs.read_file(root + "/summary.jsonl").text()
  assert_true(summary.contains("\"id\":\"first\""))
  assert_true(summary.contains("\"id\":\"second\""))
  assert_true(summary.contains("\"run_id\":\"run-wbtest\""))
  assert_true(summary.contains("\"reproducibility_status\":\"partial\""))
  let saved = @fs.read_file(root + "/run-metadata.json").text()
  assert_true(saved.contains("\"run_id\":\"run-wbtest\""))
  let markdown = @fs.read_file(root + "/summary.md").text()
  assert_true(markdown.contains("Run: run-wbtest"))
  assert_true(markdown.contains("| first |"))
  assert_true(markdown.contains("| second |"))
}

///|
async test "execution failures retain evidence for lifecycle diagnosis" {
  let root = @fs.tmpdir(prefix="mooncmd-lifecycle-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let report_dir = root + "/reports"
  @fs.mkdir(report_dir, recursive=true)
  let fixture : Case = @json.from_json({
    "id": "missing-candidate",
    "command": "missing",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let report = execute_contract(
    fixture,
    root + "/no-build-artifacts",
    false,
    report_dir,
  )
  assert_eq(report.result, "infra")
  assert_true(report.stage == "fixture" || report.stage == "candidate")
  match report.evidence {
    Some(path) => {
      assert_true(@fs.exists(path))
      assert_true(@fs.exists(path + "/work"))
    }
    None => fail("failed execution must retain evidence path")
  }
}

///|
async test "successful execution removes temporary evidence" {
  if host_platform() == "windows" {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-lifecycle-clean-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let artifact = root + "/cli/true"
  let report_dir = root + "/reports"
  @fs.mkdir(artifact, recursive=true)
  @fs.mkdir(report_dir, recursive=true)
  @fs.symlink(artifact + "/true.exe", target="/usr/bin/true")
  let fixture : Case = @json.from_json({
    "id": "successful-candidate",
    "command": "true",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let report = execute_contract(fixture, root, false, report_dir)
  assert_eq(report.result, "pass", msg=report.detail)
  assert_eq(report.evidence, None)
  assert_false(@fs.exists(report_dir + "/successful-candidate"))
}

///|
async test "evidence directory conflicts never overwrite prior failures" {
  let root = @fs.tmpdir(prefix="mooncmd-lifecycle-conflict-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let report_dir = root + "/reports"
  @fs.mkdir(report_dir, recursive=true)
  let fixture : Case = @json.from_json({
    "id": "conflict-candidate",
    "command": "missing",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let first = execute_contract(fixture, root, false, report_dir)
  assert_eq(first.result, "infra")
  let marker = report_dir + "/conflict-candidate/prior-evidence.txt"
  @fs.write_file(marker, "preserve these bytes")
  try execute_contract(fixture, root, false, report_dir) catch {
    error => assert_true(error.to_string().contains("evidence already exists"))
  } noraise {
    _ => fail("duplicate evidence directory must fail")
  }
  assert_eq(@fs.read_file(marker).text(), "preserve these bytes")
}

///|
async test "deadline cancellation preserves both partial streams" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/sh"])
  // The shell is only a deterministic harness observer: it emits both streams
  // before replacing itself with the direct child that the deadline cancels.
  let result = run_with_deadline(
    "/bin/sh",
    ["-c", "printf partial-out; printf partial-err >&2; exec sleep 5"],
    250,
    stdin=b"",
  )
  assert_true(result.timed_out)
  assert_eq(result.output.stdout, b"partial-out")
  assert_eq(result.output.stderr, b"partial-err")
  assert_eq(result.cleanup_error, None)
  assert_true(result.output.status != -1)
}

///|
async test "concurrent report writers reject conflicts without losing saved rows" {
  let root = @fs.tmpdir(prefix="mooncmd-report-concurrent-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let metadata = collect_run_metadata("concurrent-run")
  let reports : Array[CaseReport] = [
    {
      id: "retained-case",
      command: "true",
      result: "pass",
      verification: "contract",
      stage: "complete",
      detail: "",
      platform: host_platform(),
      backend: "native",
      source_version: "workspace",
      duration_ms: 1L,
      observations: ["status"],
      missing_observations: [],
      evidence: None,
    },
  ]
  let attempts : Array[async () -> Bool] = [
    () => {
      try write_reports_with_metadata(root, reports, metadata) catch {
        _ => false
      } noraise {
        _ => true
      }
    },
    () => {
      try write_reports_with_metadata(root, reports, metadata) catch {
        _ => false
      } noraise {
        _ => true
      }
    },
  ]
  let outcomes = @async.all(attempts, max_concurrent=2)
  assert_eq(outcomes.filter(value => value).length(), 1)
  let summary = @fs.read_file(root + "/summary.jsonl").text()
  assert_true(summary.contains("\"id\":\"retained-case\""))
  assert_false(@fs.exists(root + "/.report-write-lock"))
}

///|
async test "fixture setup failures retain the files prepared before failure" {
  let root = @fs.tmpdir(prefix="mooncmd-fixture-failure-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture : Case = @json.from_json({
    "id": "fixture-conflict",
    "command": "missing",
    "args": [],
    "files": [
      { "path": "parent", "content_text": "original" },
      { "path": "parent/child", "content_text": "unreachable" },
    ],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let report = execute_contract(fixture, root, false, root + "/reports")
  assert_eq(report.result, "infra")
  assert_eq(report.stage, "fixture")
  assert_eq(
    @fs.read_file(root + "/reports/fixture-conflict/work/parent").text(),
    "original",
  )
}

///|
async test "platform exclusions skip before launching or creating fixtures" {
  let root = @fs.tmpdir(prefix="mooncmd-platform-skip-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let fixture : Case = @json.from_json({
    "id": "platform-skipped",
    "command": "missing",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
    "host_platforms": ["unavailable-test-platform"],
  })
  let report = execute_contract(fixture, root, false, root + "/reports")
  assert_eq(report.result, "skip")
  assert_eq(report.stage, "platform")
  assert_eq(report.evidence, None)
  assert_false(@fs.exists(root + "/reports"))
}
