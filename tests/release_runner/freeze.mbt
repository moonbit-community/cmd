///|
priv struct RegistryReceipt {
  package_name : String
  version : String
  status : Int32
  response_file : String
  response_sha256 : String
} derive(FromJson)

///|
priv struct FreezeEvidence {
  schema : Int32
  candidate_hash : String
  git_revision : String
  registry : Array[RegistryReceipt]
  smoke_report_dirs : Array[String]
  semantic_report_dirs : Array[String]
} derive(FromJson)

///|
priv struct FreezeResult {
  id : String
  command : String
  result : String
  verification : String
  backend : String
  source_version : String
  run_id : String
  observations : Array[String]
  missing_observations : Array[String]
} derive(FromJson)

///|
fn sha256_identity(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value {
    if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) {
      return false
    }
  }
  true
}

///|
/// Evidence paths are interpreted relative to the evidence document.  Keep
/// this check at the boundary to reject absolute paths and parent traversal
/// before reading a retained receipt or report.
fn evidence_relative_path(
  value : String,
  label : String,
) -> String raise Failure {
  guard @testkit.safe_relative_path(value) else {
    fail("freeze evidence: \{label} must be a safe relative path")
  }
  value
}

///|
fn registry_response_checksum(
  text : String,
  name : String,
  version : String,
) -> String? {
  // The official exact-version API returns an envelope rather than an index
  // line. Retain its original response bytes instead of synthesizing receipts.
  let response = @json.parse(text) catch { _ => Json::null() }
  if response is { "module": _, "metadata": _, .. } {
    let checksum = live_registry_checksum(response, name, version) catch {
      _ => return None
    }
    return Some(checksum)
  }
  let mut matches = 0
  let mut selected_checksum = None
  for line in text.split("\n") {
    if line.trim().is_empty() {
      continue
    }
    let value = @json.parse(line.to_owned()) catch { _ => return None }
    match value {
      { "name": String(actual_name), "version": String(actual_version), .. } => {
        if actual_name != name {
          return None
        }
        if actual_version == version {
          match value {
            { "checksum": String(checksum), "yanked": False, .. } => {
              if !sha256_identity(checksum) {
                return None
              }
              matches += 1
              selected_checksum = Some(checksum)
            }
            _ => return None
          }
        }
      }
      _ => return None
    }
  }
  if matches == 1 {
    selected_checksum
  } else {
    None
  }
}

///|
fn registry_response_matches(
  text : String,
  name : String,
  version : String,
) -> Bool {
  registry_response_checksum(text, name, version) is Some(_)
}

///|
async fn read_freeze_evidence(path : String) -> FreezeEvidence {
  let evidence : FreezeEvidence = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  guard evidence.schema == 1 else { fail("freeze evidence: expected schema 1") }
  guard sha256_identity(evidence.candidate_hash) && evidence.git_revision != "" else {
    fail("freeze evidence: candidate hash and Git revision are required")
  }
  for receipt in evidence.registry {
    ignore(
      evidence_relative_path(receipt.response_file, "registry response_file"),
    )
  }
  for report in evidence.smoke_report_dirs {
    ignore(evidence_relative_path(report, "smoke_report_dirs entry"))
  }
  for report in evidence.semantic_report_dirs {
    ignore(evidence_relative_path(report, "semantic_report_dirs entry"))
  }
  evidence
}

///|
async fn candidate_for_freeze(
  root : String,
  candidate_path : String,
  registry_path~ : String,
) -> (ReleaseManifest, BaseManifest) {
  let registry = @registry.load(registry_path)
  let registry_errors = @registry.validate(registry) +
    @registry.validate_source_bindings(registry, root~)
  guard registry_errors.is_empty() else {
    fail(
      "freeze registry source validation failed: " + registry_errors.join("; "),
    )
  }
  let candidate = read_release_manifest(candidate_path)
  guard candidate.candidate == Some(true) else {
    fail("freeze requires an unpublished candidate manifest")
  }
  let base_path = resolve_base_manifest(
    @path.Path(candidate_path).dirname().to_string(),
    candidate.base_manifest,
  )
  let base = read_base_manifest(base_path)
  let errors = validate_release_manifest(candidate, base) +
    validate_package_versions(root, candidate) +
    validate_candidate_bindings(root, candidate, base, registry_path)
  guard errors.is_empty() else {
    fail("freeze candidate invalid: " + errors.join("; "))
  }
  (candidate, base)
}

///|
/// Retained receipts are supplemental evidence. Every coordinate is also
/// queried over authenticated HTTPS at the fixed official registry, and the
/// downloaded source archive must match its live registry checksum.
async fn validate_candidate_registry(
  root : String,
  candidate_path : String,
  evidence_path : String,
  registry_path~ : String,
) -> Unit {
  let (candidate, _) = candidate_for_freeze(
    root,
    candidate_path,
    registry_path~,
  )
  let evidence = read_freeze_evidence(evidence_path)
  guard evidence.candidate_hash == @testkit.manifest_digest(candidate_path) else {
    fail("freeze evidence belongs to a different candidate")
  }
  let revision = @testkit.run("git", ["-C", root, "rev-parse", "HEAD"])
  guard revision.status == 0 &&
    @utf8.decode(revision.stdout).trim() == evidence.git_revision else {
    fail("freeze evidence belongs to a different Git revision")
  }
  let expected = candidate.commands.map(row => (row.package_name, row.version))
  guard candidate.core_version is Some(core_version) else {
    fail("freeze candidate must record cli/core version")
  }
  expected.push(("cli/core", core_version))
  let seen : Set[String] = Set([])
  let seen_response_files : Set[String] = Set([])
  let directory = @path.Path(evidence_path).dirname()
  for receipt in evidence.registry {
    let coordinate = receipt.package_name + "@" + receipt.version
    guard expected.contains((receipt.package_name, receipt.version)) &&
      !seen.contains(coordinate) else {
      fail("unexpected or duplicate registry coordinate: " + coordinate)
    }
    guard receipt.status == 200 && sha256_identity(receipt.response_sha256) else {
      fail("registry receipt is unsuccessful: " + coordinate)
    }
    let response_file = evidence_relative_path(
      receipt.response_file,
      "registry response_file",
    )
    guard !seen_response_files.contains(response_file) else {
      fail("registry response file is reused: " + response_file)
    }
    seen_response_files.add(response_file)
    let body = @fs.read_file(directory.join(Path(response_file)).to_string())
    guard @testkit.sha256_bytes(body.binary()) == receipt.response_sha256 &&
      registry_response_matches(
        body.text(),
        receipt.package_name,
        receipt.version,
      ) else {
      fail("registry response identity mismatch: " + coordinate)
    }
    let verified = verify_live_registry_release(
      receipt.package_name,
      receipt.version,
      body.text(),
    )
    let live_directory = directory.join(Path("verified-registry")).to_string()
    @fs.mkdir(live_directory, recursive=true, allow_exist=true)
    let live_bytes = @utf8.encode(@testkit.canonical_json(verified) + "\n")
    write_immutable(
      live_directory + "/" + @testkit.sha256_bytes(live_bytes) + ".json",
      live_bytes,
    )
    seen.add(coordinate)
  }
  for (name, version) in expected {
    guard seen.contains(name + "@" + version) else {
      fail("missing exact registry receipt: " + name + "@" + version)
    }
  }
}

///|
fn validate_freeze_result(
  result : FreezeResult,
  run : @testkit.RunMetadata,
  candidate : ReleaseManifest,
) -> Bool {
  let row = find_command(candidate, result.command)
  guard row is Some(row) else { return false }
  result.run_id == run.run_id &&
  result.backend == "published-wasm" &&
  ["availability", "contract", "differential", "boundary"].contains(
    result.verification,
  ) &&
  result.source_version == row.package_name + "@" + row.version &&
  run.moonx_coordinates.contains(result.source_version) &&
  result.result == "pass" &&
  !result.observations.is_empty() &&
  result.missing_observations.is_empty()
}

///|
/// Even smoke evidence must identify a fixture selected by this candidate.
/// Command-only matching would admit an unrelated successful invocation.
fn freeze_smoke_covered(
  command : String,
  fixtures : Array[ReleaseCase],
  results : Array[(FreezeResult, @testkit.RunMetadata)],
) -> Bool {
  fixtures.any(fixture => {
    fixture.command == command &&
    results.any(item => {
      item.0.id == fixture.id &&
      item.0.command == command &&
      item.0.verification == verification_level(fixture, false) &&
      shared_report(
        {
          id: fixture.id,
          command,
          version: "",
          category: "passed",
          detail: "",
        },
        [fixture],
        false,
        Map([]),
      ).observations.all(observation => {
        item.0.observations.contains(observation)
      })
    })
  })
}

///|
async fn collect_freeze_results(
  paths : Array[String],
  directory : String,
  evidence : FreezeEvidence,
  candidate : ReleaseManifest,
  registry_hash : String,
  corpus_hash : String,
  oracle_profile : @testkit.OracleProfile,
) -> Array[(FreezeResult, @testkit.RunMetadata)] {
  let results : Array[(FreezeResult, @testkit.RunMetadata)] = []
  guard !paths.is_empty() else { fail("freeze requires report directories") }
  for path in paths {
    let seen_result_ids : Set[String] = Set([])
    let path = @path.Path(directory)
      .join(Path(evidence_relative_path(path, "report directory")))
      .to_string()
    let run : @testkit.RunMetadata = @json.from_json(
      @json.parse(@fs.read_file(path + "/run-metadata.json").text()),
    )
    guard @testkit.run_metadata_errors(run).is_empty() &&
      run.run_id != "" &&
      run.wasm_artifact_hash != "" &&
      run.git_revision == evidence.git_revision &&
      run.git_dirty == "false" &&
      run.manifest_hash == evidence.candidate_hash &&
      run.registry_hash == registry_hash &&
      run.case_corpus_hash == corpus_hash &&
      run.reproducibility_status == "complete" else {
      fail("freeze report has stale or incomplete provenance: " + path)
    }
    for line in @fs.read_file(path + "/summary.jsonl").text().split("\n") {
      if line.trim().is_empty() {
        continue
      }
      let result : FreezeResult = @json.from_json(@json.parse(line.to_owned()))
      if result.result == "skip" {
        continue
      }
      guard !seen_result_ids.contains(result.id) else {
        fail("freeze report contains duplicate result: " + result.id)
      }
      seen_result_ids.add(result.id)
      guard validate_freeze_result(result, run, candidate) else {
        fail("freeze report failed or has mismatched coordinate: " + result.id)
      }
      if result.verification == "differential" {
        guard @testkit.oracle_profile_errors(oracle_profile).is_empty() &&
          run.oracle_profile_id == oracle_profile.id &&
          run.oracle_image_digest == oracle_profile.image_digest &&
          run.oracle_versions_hash == oracle_profile.versions_sha256 else {
          fail(
            "freeze differential lacks immutable oracle provenance: " +
            result.id,
          )
        }
      }
      results.push((result, run))
    }
  }
  results
}

///|
fn freeze_case_covered(
  fixture : ReleaseCase,
  results : Array[(FreezeResult, @testkit.RunMetadata)],
) -> Bool {
  let required = verification_level(fixture, true)
  let expected_observations = shared_report(
      {
        id: fixture.id,
        command: fixture.command,
        version: "",
        category: "passed",
        detail: "",
      },
      [fixture],
      true,
      Map([]),
    ).observations
  results.any(item => {
    item.0.id == fixture.id &&
    item.0.command == fixture.command &&
    item.0.verification == required &&
    expected_observations.all(observation => {
      item.0.observations.contains(observation)
    })
  })
}

///|
async fn write_immutable(path : String, bytes : Bytes) -> Unit {
  if @fs.exists(path) {
    guard @fs.read_file(path).binary() == bytes else {
      fail("refusing to replace historical content: " + path)
    }
  } else {
    @fs.write_file(path, bytes)
  }
}

///|
/// Keep every original source document, including nested case collections and
/// overrides. The resolved case sidecar is the replay input; these exact bytes
/// preserve the source evidence used to construct that sidecar.
async fn collect_corpus_sources(
  path : String,
  ancestors : Array[String],
  sources : Array[(String, Bytes)],
) -> Unit {
  let path = @fs.realpath(path)
  guard !ancestors.contains(path) else {
    fail("historical corpus contains a reference cycle: " + path)
  }
  if sources.any(item => item.0 == path) {
    return
  }
  let bytes = @fs.read_file(path).binary()
  let value = @json.parse(@utf8.decode(bytes))
  sources.push((path, bytes))
  let next_ancestors = ancestors + [path]
  for field in ["case_files", "case_overrides"] {
    if value is Object(fields) && fields.get(field) is Some(Array(paths)) {
      for child in paths {
        guard child is String(child) else {
          fail("historical corpus references must be paths: " + path)
        }
        collect_corpus_sources(
          @path.Path(path).dirname().join(Path(child)).to_string(),
          next_ancestors,
          sources,
        )
      }
    }
  }
}

///|
/// Freeze only after registry and independently recorded exact MoonX runs
/// cover every command and selected behavior. All validation precedes writes.
/// Newly frozen manifests embed cases, preventing future corpus changes from
/// changing replay semantics. The previous current manifest is copied as bytes.
async fn freeze_published_snapshot(
  root : String,
  candidate_path : String,
  evidence_path : String,
  release_id : String,
  registry_path~ : String,
  oracle_profile_path~ : String,
  docker_path~ : String = "docker",
) -> Unit {
  guard release_id != "" &&
    release_id
    .iter()
    .all(char => {
      (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '-' ||
      char == '_'
    }) else {
    fail("release ID must contain letters, digits, hyphens or underscores")
  }
  validate_candidate_registry(
    root,
    candidate_path,
    evidence_path,
    registry_path~,
  )
  let (candidate, base) = candidate_for_freeze(
    root,
    candidate_path,
    registry_path~,
  )
  let evidence = read_freeze_evidence(evidence_path)
  let directory = @path.Path(evidence_path).dirname().to_string()
  let registry_hash = @testkit.manifest_digest(registry_path)
  let base_path = resolve_base_manifest(
    @path.Path(candidate_path).dirname().to_string(),
    candidate.base_manifest,
  )
  let corpus_hash = @testkit.manifest_digest(base_path)
  let oracle_profile = @testkit.read_oracle_profile(oracle_profile_path)
  let cases = selected_cases(candidate, base)
  guard !cases.is_empty() else { fail("freeze candidate selects no cases") }
  if cases.any(fixture => verification_level(fixture, true) == "differential") {
    let registry = @registry.load(registry_path)
    let required_profile_ids = registry.entries
      .filter(entry => cases.any(fixture => fixture.id == entry.case_id))
      .filter(entry => entry.oracle_profile != "")
      .map(entry => entry.oracle_profile)
    ignore(
      @testkit.verify_oracle_image(
        oracle_profile.image_digest,
        docker_path~,
        profile_path=oracle_profile_path,
        expected_profile_path=root + "/tests/runner/image/profile.json",
        required_profile_ids~,
      ),
    )
  }
  let smoke = collect_freeze_results(
    evidence.smoke_report_dirs,
    directory,
    evidence,
    candidate,
    registry_hash,
    corpus_hash,
    oracle_profile,
  )
  for row in candidate.commands {
    guard freeze_smoke_covered(row.name, cases, smoke) else {
      fail("missing exact MoonX smoke: " + row.name)
    }
  }
  let semantic = collect_freeze_results(
    evidence.semantic_report_dirs,
    directory,
    evidence,
    candidate,
    registry_hash,
    corpus_hash,
    oracle_profile,
  )
  for fixture in cases {
    guard freeze_case_covered(fixture, semantic) else {
      fail("missing published semantic evidence: " + fixture.id)
    }
  }
  let current = root + "/tests/release_runner/current"
  let historical = root + "/tests/release_runner/historical"
  let archive = historical + "/published-" + release_id + ".json"
  guard !@fs.exists(archive) else {
    fail("historical release ID already exists")
  }
  let old_bytes = @fs.read_file(current + "/published.json").binary()
  let old = read_release_manifest(current + "/published.json")
  guard @testkit.safe_relative_path(old.base_manifest) else {
    fail("current published manifest has an unsafe base manifest path")
  }
  let old_base_path = resolve_base_manifest(
    current,
    old.base_manifest,
    manifest_path=current + "/published.json",
  )
  let old_binding_errors = validate_frozen_case_binding(
    root,
    current + "/published.json",
    old_base_path,
  )
  guard old_binding_errors.is_empty() else {
    fail(old_binding_errors.join("; "))
  }
  // Preserve source bytes separately from the resolved replay corpus.
  // Neither artifact may follow a future mutable workspace case file.
  let old_base_bytes = @fs.read_file(old_base_path).binary()
  let old_sources : Array[(String, Bytes)] = []
  collect_corpus_sources(old_base_path, [], old_sources)
  old_sources.sort_by((left, right) => left.0.lexical_compare(right.0))
  let old_corpus_hash = @testkit.manifest_digest(old_base_path)
  let old_replay_bytes = old_base_bytes
  let archived_base = archive + ".base-source.json"
  let archived_cases = archive + ".cases.json"
  let published = frozen_publication(candidate)
  let published_bytes = @utf8.encode(
    @testkit.canonical_json(ToJson::to_json(published)) + "\n",
  )
  let publication_snapshot = prepare_current_snapshot(
    root,
    candidate_path,
    registry_path,
    evidence.git_revision,
    published_bytes,
    cases,
  )
  // A directory lock excludes concurrent freezes and the temporary file keeps
  // an interrupted write from truncating the current published manifest.
  let lock = current + "/.freeze-lock"
  @fs.mkdir(lock)
  defer (@fs.rmdir(lock) catch { _ => () })
  guard @fs.read_file(current + "/published.json").binary() == old_bytes else {
    fail("current published manifest changed while validating evidence")
  }
  guard @fs.read_file(old_base_path).binary() == old_base_bytes &&
    @testkit.manifest_digest(old_base_path) == old_corpus_hash else {
    fail("current published case corpus changed while preparing its archive")
  }
  for (path, bytes) in old_sources {
    guard @fs.read_file(path).binary() == bytes else {
      fail(
        "current published corpus source changed while preparing its archive: " +
        path,
      )
    }
  }
  guard @testkit.manifest_digest(candidate_path) == evidence.candidate_hash &&
    @testkit.manifest_digest(registry_path) == registry_hash &&
    @testkit.manifest_digest(base_path) == corpus_hash else {
    fail("candidate, registry or case corpus changed while validating evidence")
  }
  write_immutable(archived_base, old_base_bytes)
  write_immutable(archived_cases, old_replay_bytes)
  copy_snapshot_sidecars(current + "/published.json", archive)
  write_immutable(archive, old_bytes)
  guard @testkit.file_digest(archive) == @testkit.sha256_bytes(old_bytes) else {
    fail("archived published manifest byte hash mismatch")
  }
  guard @testkit.file_digest(archived_base) ==
    @testkit.sha256_bytes(old_base_bytes) else {
    fail("archived base manifest byte hash mismatch")
  }
  guard @testkit.file_digest(archived_cases) ==
    @testkit.sha256_bytes(old_replay_bytes) else {
    fail("archived replay corpus byte hash mismatch")
  }
  replace_current_snapshot(current + "/published.json", publication_snapshot)
}
