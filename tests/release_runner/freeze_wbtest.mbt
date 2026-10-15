///|
test "registry receipt requires exact non-yanked checksummed version" {
  let checksum = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let current = "{\"name\":\"cli/true\",\"version\":\"1.2.3\",\"checksum\":\"" +
    checksum +
    "\",\"yanked\":false}"
  assert_true(registry_response_matches(current, "cli/true", "1.2.3"))
  let old = "{\"name\":\"cli/true\",\"version\":\"0.1.0\",\"yanked\":true}"
  assert_true(
    registry_response_matches(old + "\n" + current, "cli/true", "1.2.3"),
  )
  assert_false(registry_response_matches(current, "cli/false", "1.2.3"))
  assert_false(registry_response_matches(current, "cli/true", "1.2.4"))
  assert_false(
    registry_response_matches(current + "\n" + current, "cli/true", "1.2.3"),
  )
  assert_false(
    registry_response_matches(
      current.replace_all(old="false", new="true"),
      "cli/true",
      "1.2.3",
    ),
  )
  assert_false(
    registry_response_matches("{\"success\":true}", "cli/true", "1.2.3"),
  )
  assert_false(
    registry_response_matches(
      current.replace_all(old=checksum, new=""),
      "cli/true",
      "1.2.3",
    ),
  )
}

///|
test "frozen replay locations recognize Windows paths without accepting live candidates" {
  for separator in ["/", "\\"] {
    let path = "tests/release_runner/current/published.json".replace_all(
      old="/",
      new=separator,
    )
    assert_eq(frozen_manifest_location(path), Some("current"))
    let historical = "tests/release_runner/historical/published-2026-10-11-repair.json".replace_all(
      old="/",
      new=separator,
    )
    assert_eq(frozen_manifest_location(historical), Some("historical"))
    for
      other in [
        "tests/release_runner/current/candidate.json", "tests/release_runner/custom/published.json",
        "../tests/release_runner/current/published.json", "tests/release_runner/historical/published-../../candidate.json",
      ] {
      assert_eq(
        frozen_manifest_location(other.replace_all(old="/", new=separator)),
        None,
      )
    }
  }
}

///|
test "snapshot Git paths retain repository separators on every host" {
  assert_eq(
    snapshot_repository_path(
      "/workspace", "/workspace/tests/release_runner/current/published.json",
    ),
    "tests/release_runner/current/published.json",
  )
  assert_eq(
    snapshot_child(
      "tests/release_runner/current/candidate.json", "../historical/cases.json",
    ),
    "tests/release_runner/historical/cases.json",
  )
}

///|
test "freeze distinguishes availability from semantic evidence" {
  let fixture = release_case_for_test("true-exit", "true")
  let candidate : ReleaseManifest = {
    schema: 2,
    candidate: Some(true),
    core_version: Some("0.5.0"),
    base_manifest: "active-cases.json",
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
  let run : @testkit.RunMetadata = {
    ..freeze_run_for_test(),
    run_id: "release-123",
    git_revision: "abc",
    git_dirty: "false",
    registry_hash: "registry",
    manifest_hash: "manifest",
    case_corpus_hash: "corpus",
    moonx_coordinates: ["cli/true@0.2.0"],
    oracle_profile_id: "fixed",
    oracle_image_digest: "sha256:123",
    oracle_versions_hash: "inventory",
    reproducibility_status: "complete",
  }
  let availability : FreezeResult = {
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
  assert_true(validate_freeze_result(availability, run, candidate))
  assert_false(freeze_case_covered(fixture, [(availability, run)]))
  let differential = {
    ..availability,
    verification: "differential",
    observations: [
      "status", "stdout-bytes", "stderr-bytes", "stdout", "stderr", "content", "type",
    ],
  }
  assert_true(freeze_case_covered(fixture, [(differential, run)]))
  assert_false(
    validate_freeze_result(
      { ..availability, source_version: "cli/true@latest", },
      run,
      candidate,
    ),
  )
  assert_false(
    validate_freeze_result(
      { ..availability, missing_observations: ["mode"], },
      run,
      candidate,
    ),
  )
  assert_false(
    validate_freeze_result({ ..availability, run_id: "other", }, run, candidate),
  )
  assert_false(
    validate_freeze_result({ ..availability, result: "infra", }, run, candidate),
  )
  assert_false(
    validate_freeze_result(
      { ..availability, observations: [], },
      run,
      candidate,
    ),
  )
}

///|
test "freeze evidence paths cannot escape their evidence directory" {
  assert_eq(
    evidence_relative_path("registry/true.json", "receipt"),
    "registry/true.json",
  )
  assert_true(
    (evidence_relative_path("../true.json", "receipt") catch { _ => "" }) == "",
  )
  assert_true(
    (evidence_relative_path("/tmp/true.json", "receipt") catch { _ => "" }) ==
    "",
  )
}

///|
test "semantic freeze evidence must retain observations" {
  let fixture = {
    ..release_case_for_test("observed", "true"),
    observe: Some(["mode"]),
  }
  let run : @testkit.RunMetadata = {
    ..freeze_run_for_test(),
    run_id: "release-observed",
    git_revision: "abc",
    git_dirty: "false",
    registry_hash: "registry",
    manifest_hash: "manifest",
    case_corpus_hash: "corpus",
    moonx_coordinates: ["cli/true@0.2.0"],
    oracle_profile_id: "fixed",
    oracle_image_digest: "sha256:123",
    oracle_versions_hash: "inventory",
    reproducibility_status: "complete",
  }
  let result : FreezeResult = {
    id: fixture.id,
    command: fixture.command,
    result: "pass",
    verification: "differential",
    backend: "published-wasm",
    source_version: "cli/true@0.2.0",
    run_id: run.run_id,
    observations: [],
    missing_observations: [],
  }
  assert_false(freeze_case_covered(fixture, [(result, run)]))
  assert_false(
    freeze_case_covered(fixture, [
      (
        {
          ..result,
          observations: [
            "status", "stdout-bytes", "stderr-bytes", "stdout", "stderr", "content",
            "type",
          ],
        },
        run,
      ),
    ]),
  )
  assert_true(
    freeze_case_covered(fixture, [
      (
        {
          ..result,
          observations: [
            "status", "stdout-bytes", "stderr-bytes", "stdout", "stderr", "content",
            "type", "mode",
          ],
        },
        run,
      ),
    ]),
  )
}

///|
async test "historical writes preserve bytes and reject replacement" {
  let directory = @fs.tmpdir(prefix="mooncmd-freeze-immutable")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let path = directory + "/published.json"
  write_immutable(path, b"{\"published\":true}\n")
  let original_hash = @testkit.file_digest(path)
  write_immutable(path, b"{\"published\":true}\n")
  let rejected = try write_immutable(path, b"different") catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(rejected)
  assert_eq(@testkit.file_digest(path), original_hash)
}

///|
async test "historical replay uses its resolved corpus without rewriting manifest bytes" {
  let root = @fs.tmpdir(prefix="mooncmd-frozen-replay")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let directory = root + "/historical"
  @fs.mkdir(directory)
  let manifest_path = directory + "/published-fixture.json"
  let original = b"{\"base_manifest\":\"mutable.json\"}\n"
  @fs.write_file(manifest_path, original)
  @fs.write_file(directory + "/mutable.json", "{\"schema\":2,\"cases\":[]}\n")
  let frozen : ActiveCasesIndex = {
    schema: 2,
    cases: [release_case_for_test("frozen-case", "true")],
    case_files: [],
    case_overrides: [],
  }
  let sidecar = manifest_path + ".cases.json"
  write_immutable(sidecar, @utf8.encode(ToJson::to_json(frozen).stringify()))
  let resolved = resolve_base_manifest(
    directory,
    "mutable.json",
    manifest_path~,
  )
  assert_eq(resolved, sidecar)
  assert_eq(read_base_manifest(resolved).cases.map(item => item.id), [
    "frozen-case",
  ])
  assert_eq(@fs.read_file(manifest_path).binary(), original)
}

///|
async test "historical corpus archive preserves nested source bytes and rejects cycles" {
  let root = @fs.tmpdir(prefix="mooncmd-corpus-sources")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let original = b"{ \"cases\": [] }\n"
  @fs.write_file(root + "/leaf.json", original)
  @fs.write_file(
    root + "/middle.json",
    "{\"case_overrides\":[\"leaf.json\"]}\n",
  )
  @fs.write_file(
    root + "/index.json",
    "{\"case_files\":[\"middle.json\",\"leaf.json\"]}\n",
  )
  let sources : Array[(String, Bytes)] = []
  collect_corpus_sources(root + "/index.json", [], sources)
  assert_eq(sources.length(), 3)
  sources.sort_by((left, right) => left.0.lexical_compare(right.0))
  let archive = root + "/archive"
  @fs.mkdir(archive)
  for (_, bytes) in sources {
    write_immutable(
      archive + "/" + @testkit.sha256_bytes(bytes) + ".json",
      bytes,
    )
  }
  let saved = archive + "/" + @testkit.sha256_bytes(original) + ".json"
  assert_true(@fs.read_file(saved).binary() == original)
  @fs.write_file(root + "/leaf.json", "{\"cases\":[]}")
  assert_true(@fs.read_file(saved).binary() == original)
  @fs.write_file(root + "/cycle.json", "{\"case_files\":[\"cycle.json\"]}")
  let rejected = try
    collect_corpus_sources(root + "/cycle.json", [], [])
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(rejected)
}

///|
async test "current published metadata remains separate from candidate generation" {
  let root = workspace_root()
  let current = root + "/tests/release_runner/current"
  let published = read_release_manifest(current + "/published.json")
  let candidate = read_release_manifest(current + "/candidate.json")
  assert_true(published.base_manifest != candidate.base_manifest)
  let path = resolve_base_manifest(
    current,
    published.base_manifest,
    manifest_path=current + "/published.json",
  )
  assert_eq(
    validate_frozen_case_binding(root, current + "/published.json", path),
    [],
  )
}

///|
fn freeze_run_for_test() -> @testkit.RunMetadata {
  let digest = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let environments : Array[@testkit.ExecutionEnvironment] = [
    {
      program: "fixture",
      inherit_env: true,
      values: { "LC_ALL": "C", "TZ": "UTC" },
    },
  ]
  {
    schema: 1,
    run_id: "freeze-test",
    git_revision: "fixture-revision",
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
    moonx_coordinates: ["cli/true@0.2.0"],
    platform: "linux",
    os: "Linux",
    architecture: "x86_64",
    locale: "C",
    timezone: "UTC",
    docker_version: "",
    policy_hash: digest,
    environment_fingerprint: @testkit.execution_environment_digest(environments),
    host_environment_fingerprint: digest,
    execution_environments: environments,
    started_at_ms: 1L,
    ended_at_ms: 2L,
    reproducibility_status: "complete",
  }
}

///|
test "freeze metadata complete label cannot conceal missing reproducibility fields" {
  let run = freeze_run_for_test()
  assert_true(@testkit.run_metadata_errors(run).is_empty())
  assert_false(
    @testkit.run_metadata_errors({ ..run, toolchain: "", }).is_empty(),
  )
  assert_false(
    @testkit.run_metadata_errors({ ..run, policy_hash: "", }).is_empty(),
  )
  assert_false(
    @testkit.run_metadata_errors({ ..run, wasm_artifact_hash: "", }).is_empty(),
  )
  assert_false(
    @testkit.run_metadata_errors({ ..run, ended_at_ms: 0L, }).is_empty(),
  )
  assert_false(
    @testkit.run_metadata_errors({
      ..run,
      execution_environments: [],
      environment_fingerprint: @testkit.execution_environment_digest([]),
    }).is_empty(),
  )
  let truncated : Json = {
    "run_id": "forged",
    "reproducibility_status": "complete",
  }
  let rejected = try {
    let _run : @testkit.RunMetadata = @json.from_json(truncated)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
async test "freeze live registry verification rejects fabricated receipts and wrong archives" {
  let archive = b"verified registry source bytes"
  let checksum = @testkit.sha256_bytes(archive)
  let manifest : Json = {
    "module": "cli/true",
    "version": "0.2.0",
    "yanked": false,
    "metadata": {
      "name": "cli/true",
      "version": "0.2.0",
      "checksum": Json(checksum),
    },
  }
  let receipt : Json = {
    "name": "cli/true",
    "version": "0.2.0",
    "yanked": false,
    "checksum": Json(checksum),
  }
  let requests : Array[String] = []
  let verified = verify_live_registry_release_with(
    "cli/true",
    "0.2.0",
    receipt.stringify(),
    url => {
      requests.push(url)
      if url.has_suffix(".zip") {
        (200, archive)
      } else {
        (200, @utf8.encode(manifest.stringify()))
      }
    },
  )
  assert_eq(requests, [
    "https://mooncakes.io/api/v0/manifest/cli/true@0.2.0", "https://download.mooncakes.io/user/cli/true/0.2.0.zip",
  ])
  assert_true(
    verified is { "archive_sha256": String(actual), .. } && actual == checksum,
  )
  let forged = receipt
    .stringify()
    .replace_all(
      old=checksum,
      new="0000000000000000000000000000000000000000000000000000000000000000",
    )
  let forged_rejected = try {
    ignore(
      verify_live_registry_release_with("cli/true", "0.2.0", forged, _ => {
        (200, @utf8.encode(manifest.stringify()))
      }),
    )
    false
  } catch {
    _ => true
  }
  assert_true(forged_rejected)
  let archive_rejected = try {
    ignore(
      verify_live_registry_release_with(
        "cli/true",
        "0.2.0",
        receipt.stringify(),
        url => {
          if url.has_suffix(".zip") {
            (200, b"corrupted")
          } else {
            (200, @utf8.encode(manifest.stringify()))
          }
        },
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(archive_rejected)
  let redirect_rejected = try {
    ignore(
      verify_live_registry_release_with(
        "cli/true",
        "0.2.0",
        receipt.stringify(),
        _ => (302, b"redirect"),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(redirect_rejected)
}

///|
test "freeze registry endpoint cannot be replaced by a receipt coordinate" {
  for
    coordinate in [
      "other/true", "cli/../true", "cli/true?host=other", "https://elsewhere/true",
    ] {
    let rejected = try {
      ignore(freeze_registry_urls(coordinate, "0.2.0"))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for version in ["latest", "0.2.0?url=elsewhere", "../0.2.0"] {
    let rejected = try {
      ignore(freeze_registry_urls("cli/true", version))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "frozen replay rejects modified corpus even with a matching local hash" {
  let source_root = workspace_root()
  let root = @fs.tmpdir(prefix="mooncmd-frozen-tamper")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = source_root + "/tests/release_runner/current/published.json"
  let manifest = root + "/tests/release_runner/current/published.json"
  @fs.mkdir(root + "/tests/release_runner/current", recursive=true)
  @fs.mkdir(root + "/tests/registry", recursive=true)
  @fs.write_file(
    root + "/tests/registry/baseline.json",
    @fs.read_file(source_root + "/tests/registry/baseline.json").binary(),
  )
  @fs.write_file(manifest, @fs.read_file(source).binary())
  copy_snapshot_sidecars(source, manifest)
  // Share only the already recorded Git objects with the isolated fixture.
  let git_directory = @utf8.decode(
      snapshot_git(source_root, ["rev-parse", "--absolute-git-dir"]),
    )
    .trim()
    .to_owned()
  @fs.write_file(root + "/.git", "gitdir: " + git_directory + "\n")
  let corpus = manifest + ".cases.json"
  let valid = validate_frozen_case_binding(root, manifest, corpus)
  assert_eq(valid, [])
  let forged = snapshot_corpus_bytes([])
  @fs.write_file(corpus, forged)
  let provenance : FrozenProvenance = @json.from_json(
    @json.parse(@fs.read_file(manifest + ".provenance.json").text()),
  )
  let provenance = {
    ..provenance,
    corpus_sha256: @testkit.sha256_bytes(forged),
  }
  @fs.write_file(
    manifest + ".provenance.json",
    @testkit.canonical_json(ToJson::to_json(provenance)),
  )
  let errors = validate_frozen_case_binding(root, manifest, corpus)
  assert_false(errors.is_empty())
}

///|
async test "all migrated historical release corpora verify against recorded Git sources" {
  let root = workspace_root()
  let historical = root + "/tests/release_runner/historical"
  for
    name in [
      "published-0.1.0.json", "published-0.1.1.json", "published-0.2.0.json", "published-2026-10-10.json",
      "published-2026-10-11.json", "published-2026-10-11-repair.json",
    ] {
    let path = historical + "/" + name
    let failures = validate_frozen_case_binding(
      root,
      path,
      path + ".cases.json",
    )
    assert_eq(failures, [])
  }
}
