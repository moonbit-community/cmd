///|
fn partial_candidate_for_test() -> ReleaseManifest {
  {
    schema: 2,
    candidate: Some(true),
    release_scope: Some(["curl", "mv", "wget"]),
    core_version: Some("0.7.0"),
    base_manifest: "cases.json",
    commands: ["curl", "mv", "true", "wget"].map(name => {
      name,
      package_name: "cli/" + name,
      version: "0.2.3",
      published: false,
      compare_profile: "gnu",
      supported_options: [],
      policy_sensitive: false,
    }),
    case_ids: [],
    extra_cases: [],
  }
}

///|
test "partial release scope limits execution without shrinking candidate inventory" {
  let candidate = partial_candidate_for_test()
  assert_eq(release_scope_errors(candidate), [])
  assert_eq(candidate.commands.length(), 4)
  assert_eq(release_commands(candidate).map(row => row.name), [
    "curl", "mv", "wget",
  ])
  let cases = candidate.commands.map(row => {
    release_case_for_test(row.name, row.name)
  })
  let base : BaseManifest = { schema: 2, cases, }
  assert_eq(selected_cases(candidate, base).length(), 4)
  assert_eq(release_cases(candidate, base).map(fixture => fixture.command), [
    "curl", "mv", "wget",
  ])
  let full = { ..candidate, release_scope: None, }
  assert_eq(release_commands(full).length(), 4)
  assert_eq(release_cases(full, base).length(), 4)
  for scope in [[], ["curl", "curl"], ["wget", "curl"], ["missing"]] {
    assert_false(
      release_scope_errors({ ..candidate, release_scope: Some(scope), }).is_empty(),
    )
  }
  assert_false(
    release_scope_errors({ ..candidate, candidate: Some(false), }).is_empty(),
  )
}

///|
test "published network scenarios require exact adapters and complete command scope" {
  let candidate = partial_candidate_for_test()
  for
    (id, comparison) in [
      ("network-auth-cookie", "scenario"),
      ("network-auth-cookie-oracle", "oracle-scenario"),
      ("network-transfer-boundaries", "scenario"),
      ("network-transfer-boundaries-oracle", "oracle-scenario"),
    ] {
    let fixture = {
      ..release_case_for_test(id, "curl"),
      related_commands: Some(["wget"]),
      comparison: Some(comparison),
      oracle: Some(comparison == "oracle-scenario"),
    }
    assert_true(release_network_scenario(fixture))
    assert_false(release_network_scenario({ ..fixture, id: "other-scenario", }))
    assert_false(
      release_network_scenario({ ..fixture, related_commands: None, }),
    )
    let base : BaseManifest = { schema: 2, cases: [fixture], }
    assert_false(
      validate_release_manifest(candidate, base).any(error => {
        error.contains("related command")
      }),
    )
    let incomplete = { ..candidate, release_scope: Some(["curl"]), }
    assert_true(
      validate_release_manifest(incomplete, base).any(error => {
        error.contains("related command wget")
      }),
    )
    let related_only = { ..candidate, release_scope: Some(["wget"]), }
    assert_eq(release_cases(related_only, base).length(), 1)
    assert_true(
      validate_release_manifest(related_only, base).any(error => {
        error.contains("related command curl")
      }),
    )
  }
}

///|
test "partial release preserves unselected coordinates and rejects retained case identity collisions" {
  let candidate = partial_candidate_for_test()
  let previous = frozen_publication({
    ..candidate,
    release_scope: None,
    core_version: Some("0.6.0"),
    commands: candidate.commands.map(row => { ..row, version: "0.2.2", }),
  })
  let published = partial_publication(candidate, previous)
  assert_eq(published.release_scope, None)
  assert_eq(published.commands.length(), previous.commands.length())
  assert_eq(published.core_version, Some("0.7.0"))
  for row in published.commands {
    assert_true(row.published)
    assert_eq(row.version, if row.name == "true" { "0.2.2" } else { "0.2.3" })
  }
  let old = [
    release_case_for_test("retained", "true"),
    release_case_for_test("old-curl", "curl"),
  ]
  let fresh = release_case_for_test("new-curl", "curl")
  assert_eq(
    partial_publication_cases(candidate, old, [fresh]).map(fixture => fixture.id),
    ["retained", "new-curl"],
  )
  for
    collision in [
      { ..fresh, id: "retained", },
      { ..fresh, aliases: Some(["retained"]), },
      { ..fresh, command: "true", },
    ] {
    let rejected = try {
      ignore(partial_publication_cases(candidate, old, [collision]))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "freeze evidence requires release scope and actual applicable host" {
  let candidate = partial_candidate_for_test()
  let fixture = {
    ..release_case_for_test("windows-mv", "mv"),
    host_platforms: Some(["windows"]),
    comparison: Some("contract"),
    expected_stdout_text: Some(""),
    expected_stderr_text: Some(""),
  }
  let run = { ..freeze_run_for_test(), moonx_coordinates: ["cli/mv@0.2.3"], }
  let result : FreezeResult = {
    id: fixture.id,
    command: "mv",
    result: "pass",
    verification: "contract",
    backend: "published-wasm",
    source_version: "cli/mv@0.2.3",
    run_id: run.run_id,
    observations: ["status", "stdout", "stderr", "stdout-bytes", "stderr-bytes"],
    missing_observations: [],
  }
  assert_true(validate_freeze_result(result, run, candidate))
  assert_false(
    validate_freeze_result(
      { ..result, command: "true", source_version: "cli/true@0.2.3", },
      run,
      candidate,
    ),
  )
  assert_false(
    validate_freeze_result(
      result,
      { ..run, moonx_coordinates: ["cli/mv@0.2.3", "cli/wget@0.2.2"], },
      candidate,
    ),
  )
  assert_false(freeze_case_covered(fixture, [(result, run)]))
  assert_false(freeze_smoke_covered("mv", [fixture], [(result, run)]))
  let windows = { ..run, platform: "windows", }
  assert_true(freeze_case_covered(fixture, [(result, windows)]))
  assert_true(freeze_smoke_covered("mv", [fixture], [(result, windows)]))
  let shared = { ..fixture, related_commands: Some(["wget"]), }
  assert_false(freeze_case_covered(shared, [(result, windows)]))
  assert_true(
    freeze_case_covered(shared, [
      (
        result,
        { ..windows, moonx_coordinates: ["cli/mv@0.2.3", "cli/wget@0.2.3"], },
      ),
    ]),
  )
}

///|
/// The fixture owns its Git index and commits; the source repository supplies
/// existing objects read-only. This exercises committed predecessor replay,
/// including forged local hashes, without altering the real release files.
async test "partial frozen publication replays committed predecessor and rejects forged retained contracts" {
  let source_root = workspace_root()
  let directory = @fs.tmpdir(prefix="mooncmd-partial-freeze")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  let root = directory + "/repository"
  let cloned = @testkit.run("git", [
    "clone", "--shared", "--no-checkout", source_root, root,
  ])
  assert_eq(cloned.status, 0)
  let relative = "tests/release_runner/current/published.json"
  let current = root + "/tests/release_runner/current"
  @fs.mkdir(current, recursive=true)
  @fs.mkdir(root + "/tests/registry", recursive=true)
  @fs.write_file(
    root + "/tests/registry/baseline.json",
    @fs.read_file(source_root + "/tests/registry/baseline.json").binary(),
  )
  @fs.write_file(
    root + "/" + relative,
    @fs.read_file(source_root + "/" + relative).binary(),
  )
  copy_snapshot_sidecars(source_root + "/" + relative, root + "/" + relative)
  let previous = read_release_manifest(root + "/" + relative)
  let old_cases = read_base_manifest(root + "/" + relative + ".cases.json").cases
  let source_candidate = read_release_manifest(
    source_root + "/tests/release_runner/current/candidate.json",
  )
  let candidate = {
    ..source_candidate,
    release_scope: Some(["curl", "mv", "wget"]),
  }
  let base = read_base_manifest(
    resolve_base_manifest(
      source_root + "/tests/release_runner/current",
      source_candidate.base_manifest,
    ),
  )
  let candidate_path = current + "/candidate.json"
  @fs.write_file(candidate_path, ToJson::to_json(candidate).stringify())
  @fs.write_file(
    current + "/active-cases.json",
    snapshot_corpus_bytes(base.cases),
  )
  let registry_path = root + "/tests/registry/registry.json"
  @fs.write_file(
    registry_path,
    @fs.read_file(source_root + "/tests/registry/registry.json").binary(),
  )
  ignore(snapshot_git(root, ["add", "--force", "tests"]))
  let hooks = directory + "/empty-hooks"
  @fs.mkdir(hooks)
  ignore(
    snapshot_git(root, [
      "-c",
      "user.name=Release fixture",
      "-c",
      "user.email=release-fixture@example.invalid",
      "-c",
      "core.hooksPath=" + hooks,
      "commit",
      "--no-verify",
      "--no-gpg-sign",
      "-m",
      "Scoped release fixture",
    ]),
  )
  let revision = @utf8.decode(snapshot_git(root, ["rev-parse", "HEAD"]))
    .trim()
    .to_owned()
  let published = partial_publication(candidate, previous)
  let published_bytes = @utf8.encode(
    @testkit.canonical_json(publication_json(published)) + "\n",
  )
  let selected = release_cases(candidate, base)
  let snapshot = prepare_current_snapshot(
    root, candidate_path, registry_path, revision, published_bytes, selected,
  )
  replace_current_snapshot(current + "/published.json", snapshot)
  assert_eq(
    validate_frozen_case_binding(
      root,
      current + "/published.json",
      current + "/published.json.cases.json",
    ),
    [],
  )
  let frozen = read_release_manifest(current + "/published.json")
  assert_eq(frozen.commands.length(), previous.commands.length())
  for row in previous.commands {
    if !release_includes(candidate, row.name) {
      assert_eq(
        @testkit.canonical_json(ToJson::to_json(find_command(frozen, row.name))),
        @testkit.canonical_json(ToJson::to_json(Some(row))),
      )
    }
  }
  let frozen_cases = read_base_manifest(current + "/published.json.cases.json").cases
  assert_eq(
    snapshot_corpus_bytes(
      frozen_cases.filter(fixture => {
        !release_includes(candidate, fixture.command)
      }),
    ),
    snapshot_corpus_bytes(
      old_cases.filter(fixture => !release_includes(candidate, fixture.command)),
    ),
  )
  let retained = previous.commands
    .iter()
    .find_first(row => !release_includes(candidate, row.name))
    .unwrap()
  let forged = {
    ..frozen,
    commands: frozen.commands.map(row => {
      if row.name == retained.name {
        { ..row, version: "99.0.0", }
      } else {
        row
      }
    }),
  }
  let forged_bytes = @utf8.encode(
    @testkit.canonical_json(publication_json(forged)),
  )
  @fs.write_file(current + "/published.json", forged_bytes)
  let provenance : FrozenProvenance = @json.from_json(
    @json.parse(
      @fs.read_file(current + "/published.json.provenance.json").text(),
    ),
  )
  @fs.write_file(
    current + "/published.json.provenance.json",
    ToJson::to_json({
      ..provenance,
      manifest_sha256: @testkit.sha256_bytes(forged_bytes),
    }).stringify(),
  )
  assert_false(
    validate_frozen_case_binding(
      root,
      current + "/published.json",
      current + "/published.json.cases.json",
    ).is_empty(),
  )
  replace_current_snapshot(current + "/published.json", snapshot)
  let forged_cases = snapshot_corpus_bytes(
    frozen_cases.filter(fixture => fixture.command != retained.name),
  )
  @fs.write_file(current + "/published.json.cases.json", forged_cases)
  @fs.write_file(
    current + "/published.json.provenance.json",
    ToJson::to_json({
      ..provenance,
      corpus_sha256: @testkit.sha256_bytes(forged_cases),
    }).stringify(),
  )
  assert_false(
    validate_frozen_case_binding(
      root,
      current + "/published.json",
      current + "/published.json.cases.json",
    ).is_empty(),
  )
  replace_current_snapshot(current + "/published.json", snapshot)
  let predecessor = provenance.predecessor.unwrap()
  @fs.write_file(
    current + "/published.json.provenance.json",
    ToJson::to_json({
      ..provenance,
      predecessor: Some({
        ..predecessor,
        provenance_sha256: predecessor.manifest_sha256,
      }),
    }).stringify(),
  )
  assert_false(
    validate_frozen_case_binding(
      root,
      current + "/published.json",
      current + "/published.json.cases.json",
    ).is_empty(),
  )
  let cyclic = try {
    ignore(
      verified_predecessor(root, revision, predecessor, [
        revision + ":" + predecessor.manifest_path,
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(cyclic)
}
