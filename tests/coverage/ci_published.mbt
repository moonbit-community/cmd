///|
priv struct CiFrozenBinding {
  manifest_hash : String
  corpus_hash : String
  registry_hash : String
  corpus_path : String
  coordinates : Array[String]
}

///|
fn ci_impact_needs_published(
  impact : CiImpact,
  registry : @registry.Registry,
) -> Bool raise {
  let mut required = impact.required_evidence.contains("published-differential")
  for id in impact.affected_behaviors {
    guard find_entry(registry, id) is Some(entry) else {
      fail("CI impact names an unknown behavior: " + id)
    }
    if entry.required_evidence.contains("published-differential") {
      required = true
    }
  }
  required
}

///|
async fn ci_published_enabled(
  context : CiContext,
  intent : @scope.ScopeIntent?,
) -> Bool {
  if context.base == "" {
    return true
  }
  guard intent is Some(intent) else {
    fail("published execution requires the fresh actual-range scope")
  }
  context.event == "workflow_dispatch" ||
  ci_scope_needs_published(intent) ||
  ci_impact_needs_published(
    ci_scope_impact(intent),
    @registry.load("tests/registry/registry.json"),
  )
}

///|
fn ci_scope_needs_published(intent : @scope.ScopeIntent) -> Bool {
  intent.selection.mode == "full" ||
  intent.selection.requirements.any(row => {
    row.evidence.contains("published-differential")
  }) ||
  ci_scope_impact(intent).published_manifest_affected
}

///|
async fn ci_requirements(context : CiContext) -> Unit {
  let intent = ci_scope_preflight(context)
  let published = ci_published_enabled(context, intent)
  let output = "published_differential=" + published.to_string() + "\n"
  guard @env.get_env_var("GITHUB_OUTPUT") is Some(path) else {
    fail("requirements probe requires the workflow step output path")
  }
  @fs.write_file(path, output, append=true, create_mode=OpenOrCreate)
}

///|
// The executable is built from the same clean checkout. Reuse its complete
// Git-backed snapshot validation rather than accepting self-authored hashes.
async fn ci_frozen_binding() -> CiFrozenBinding {
  let manifest = "tests/release_runner/current/published.json"
  let result = @shell.Cmd(
    "./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe",
    ["--manifest", manifest, "--suite", "validate"],
  ).output(timeout_ms=120000)
  guard result.exit_code() == 0 else {
    fail("CI frozen publication validation failed: " + result.stderr())
  }
  let binding : CiFrozenBinding = {
    manifest_hash: @testkit.manifest_digest(manifest),
    corpus_hash: @testkit.manifest_digest(manifest + ".cases.json"),
    registry_hash: @testkit.manifest_digest(manifest + ".registry.json"),
    corpus_path: manifest + ".cases.json",
    coordinates: manifest_coordinates(manifest),
  }
  guard valid_sha256(binding.manifest_hash) &&
    valid_sha256(binding.corpus_hash) &&
    valid_sha256(binding.registry_hash) &&
    !binding.coordinates.is_empty() else {
    fail("CI frozen publication inputs are incomplete")
  }
  binding
}

///|
fn ci_frozen_metadata_matches(
  metadata : AuditRunMetadata,
  binding : CiFrozenBinding,
) -> Bool {
  metadata.platform == "linux" &&
  metadata.manifest_hash == binding.manifest_hash &&
  metadata.case_corpus_hash == binding.corpus_hash &&
  metadata.registry_hash == binding.registry_hash &&
  !binding.coordinates.is_empty() &&
  metadata.moonx_coordinates.length() ==
  sorted_unique(metadata.moonx_coordinates.copy()).length() &&
  binding.coordinates.length() ==
  sorted_unique(binding.coordinates.copy()).length() &&
  sorted_unique(metadata.moonx_coordinates.copy()) ==
  sorted_unique(binding.coordinates.copy())
}

///|
priv struct CiFrozenPublicationProof {
  status : String
  required_case_ids : Array[String]
  required_coordinates : Array[String]
  observed_row_count : Int32
  report_paths : Array[String]
  run_ids : Array[String]
  findings : Array[String]
} derive(ToJson)

///|
fn ci_frozen_publication_metadata_path(path : String) -> Bool {
  path
  .replace_all(old="\\", new="/")
  .has_suffix("/published-differential/run-metadata.json")
}

///|
async fn ci_frozen_cases(
  manifest_path : String,
  binding : CiFrozenBinding,
) -> Array[@testkit.Case] {
  let value = @scope.strict_json(@fs.read_file(manifest_path).text())
  guard value is { "case_ids": ids, "extra_cases": extras, .. } else {
    fail("frozen publication has no explicit case selection")
  }
  let requested : Array[String] = @json.from_json(ids)
  let extra_cases : Array[@testkit.Case] = @json.from_json(extras)
  let all = @testkit.load_cases(binding.corpus_path) + extra_cases
  if requested.is_empty() {
    return all
  }
  let selected = extra_cases.copy()
  let included : Set[String] = Set::from_array(selected.map(item => item.id))
  for id in requested {
    guard all.any(item => {
      item.id == id || item.aliases.unwrap_or([]).contains(id)
    }) else {
      fail("frozen publication selects an unknown case: " + id)
    }
    for fixture in all {
      if (fixture.id == id || fixture.aliases.unwrap_or([]).contains(id)) &&
        !included.contains(fixture.id) {
        selected.push(fixture)
        included.add(fixture.id)
      }
    }
  }
  selected
}

///|
fn ci_frozen_verification(
  entry : @registry.RegistryEntry,
  fixture : @testkit.Case,
) -> String raise {
  if entry.status == "boundary" ||
    fixture.expected_rejection is Some(_) ||
    fixture.comparison == Some("boundary") {
    guard entry.status == "boundary" &&
      entry.required_evidence.contains("boundary") else {
      fail("frozen rejection has no matching boundary registry requirement")
    }
    return "boundary"
  }
  if fixture.oracle == Some(true) ||
    fixture.comparison == Some("oracle-scenario") {
    return "differential"
  }
  match fixture.comparison {
    Some("contract" | "scenario") => "contract"
    None | Some("differential" | "exact" | "normalized") => "differential"
    _ => fail("unsupported frozen publication verification profile")
  }
}

///|
fn ci_frozen_observations(
  entry : @registry.RegistryEntry,
  fixture : @testkit.Case,
  verification : String,
) -> Array[String] {
  let observations = entry.observations +
    @testkit.contract_observations(fixture)
  observations.push("status")
  if @network_scenarios.supports(fixture.id) &&
    (
      fixture.comparison == Some("scenario") ||
      fixture.comparison == Some("oracle-scenario")
    ) {
    observations.append(@network_scenarios.observations(fixture.id))
  } else if verification == "boundary" {
    observations.append([
      "nonzero-status", "diagnostic", "stderr", "content", "type",
    ])
  } else if verification == "differential" {
    observations.append(["stdout", "stderr", "content", "type"])
  }
  if fixture.expected_stdout_hex is Some(_) ||
    fixture.expected_stdout_text is Some(_) ||
    fixture.expected_stdout_contains is Some(_) ||
    !fixture.expected_stdout_contains_all.unwrap_or([]).is_empty() ||
    fixture.expected_stdout_ends_with_newline is Some(_) {
    observations.push("stdout")
  }
  if fixture.expected_stderr_hex is Some(_) ||
    fixture.expected_stderr_text is Some(_) ||
    fixture.expected_stderr_contains is Some(_) ||
    !fixture.expected_stderr_contains_all.unwrap_or([]).is_empty() ||
    fixture.expected_stderr_ends_with_newline is Some(_) ||
    fixture.forbidden_stderr is Some(_) {
    observations.push("stderr")
  }
  sorted_unique(observations)
}

///|
// The frozen selected bodies and their registry are an independent proof
// subject. No current source row or current canonical case enters this check.
fn ci_frozen_publication_errors(
  binding : CiFrozenBinding,
  registry : @registry.Registry,
  cases : Array[@testkit.Case],
  coordinates : Map[String, String],
  bundle : EvidenceBundle,
) -> Array[String] {
  let failures = @registry.validate_frozen_registry(registry)
  failures.append(@testkit.run_metadata_errors(bundle.metadata))
  if bundle.metadata.git_dirty != "false" ||
    bundle.metadata.reproducibility_status != "complete" {
    failures.push("frozen publication metadata is dirty or incomplete")
  }
  if !valid_sha256(bundle.metadata.wasm_artifact_hash) {
    failures.push(
      "frozen publication requires its exact Wasm artifact identity",
    )
  }
  if cases.is_empty() || registry.entries.is_empty() {
    failures.push(
      "frozen publication requires nonempty selected cases and registry",
    )
  }
  if !ci_frozen_metadata_matches(bundle.metadata, binding) ||
    sorted_unique(coordinates.values().collect()) !=
    sorted_unique(binding.coordinates.copy()) ||
    coordinates.length() != binding.coordinates.length() ||
    sorted_unique(bundle.published_coordinates.copy()) !=
    sorted_unique(binding.coordinates.copy()) ||
    bundle.published_coordinates.length() != binding.coordinates.length() {
    failures.push("frozen publication requires every exact coordinate once")
  }
  let ids = cases.map(fixture => fixture.id)
  if sorted_unique(ids.copy()).length() != ids.length() ||
    sorted_unique(bundle.selected_ids.copy()) != sorted_unique(ids.copy()) ||
    bundle.selected_ids.length() != ids.length() {
    failures.push(
      "frozen publication selected case identities are incomplete or duplicated",
    )
  }
  if bundle.rows.length() != cases.length() {
    failures.push(
      "frozen publication requires one actual row per selected case",
    )
  }
  for row in bundle.rows {
    if !ids.contains(row.id) {
      failures.push("unexpected frozen publication row: " + row.id)
    }
  }
  for fixture in cases {
    let entries = registry.entries.filter(entry => {
      entry.is_case() && entry.case_id == fixture.id
    })
    guard entries is [entry] && entry.command == fixture.command else {
      failures.push(
        "frozen case lacks its exact frozen registry owner: " + fixture.id,
      )
      continue
    }
    guard coordinates.get(fixture.command) is Some(coordinate) else {
      failures.push(
        "frozen case has no exact published coordinate: " + fixture.id,
      )
      continue
    }
    let rows = bundle.rows.filter(row => row.id == fixture.id)
    guard rows is [row] else {
      failures.push(
        "missing or repeated frozen publication case: " + fixture.id,
      )
      continue
    }
    for problem in validate_row_identity(row, bundle.metadata) {
      failures.push(fixture.id + ": " + problem)
    }
    if row.backend != "published-wasm" ||
      row.platform != "linux" ||
      row.source_version != coordinate ||
      !row.missing_observations.is_empty() {
      failures.push(
        "frozen case has mismatched artifact, platform, coordinate or observations: " +
        fixture.id,
      )
    }
    let verification = ci_frozen_verification(entry, fixture) catch {
      error => {
        failures.push(fixture.id + ": " + error.to_string())
        continue
      }
    }
    if row.verification != verification {
      failures.push("frozen case has substituted verification: " + fixture.id)
    }
    let applies = match fixture.host_platforms {
      None => true
      Some(platforms) =>
        platforms.contains("linux") || platforms.contains("posix")
    }
    if platform_applies(entry, "linux") != applies {
      failures.push(
        "frozen case and registry disagree on Linux applicability: " +
        fixture.id,
      )
    }
    if !applies {
      if row.result != "skip" {
        failures.push(
          "non-Linux frozen case requires its explicit platform skip: " +
          fixture.id,
        )
      }
      continue
    }
    if row.result != "pass" || row.verification != verification {
      failures.push(
        "frozen case did not pass its required " +
        verification +
        " verification: " +
        fixture.id,
      )
    }
    if verification == "differential" &&
      (
        !bundle.oracle_verified ||
        entry.oracle_profile == "" ||
        bundle.metadata.oracle_profile_id != entry.oracle_profile
      ) {
      failures.push(
        "frozen differential lacks its sealed immutable oracle: " + fixture.id,
      )
    }
    for observation in ci_frozen_observations(entry, fixture, verification) {
      if !observation_matches(row.observations, observation) {
        failures.push(
          "frozen case lacks required observation " +
          observation +
          ": " +
          fixture.id,
        )
      }
    }
  }
  failures
}

///|
async fn ci_prove_frozen_publication(
  binding : CiFrozenBinding,
  metadata_paths : Array[String],
  profiles : Array[String],
  head : String,
) -> CiFrozenPublicationProof {
  let manifest_path = "tests/release_runner/current/published.json"
  guard @testkit.manifest_digest(manifest_path) == binding.manifest_hash &&
    @testkit.manifest_digest(manifest_path + ".registry.json") ==
    binding.registry_hash &&
    @testkit.manifest_digest(binding.corpus_path) == binding.corpus_hash else {
    fail("frozen publication inputs changed after provenance validation")
  }
  let registry = @registry.load(manifest_path + ".registry.json")
  let cases = ci_frozen_cases(manifest_path, binding)
  let manifest = @scope.strict_json(@fs.read_file(manifest_path).text())
  guard manifest is { "commands": Array(commands), .. } else {
    fail("frozen publication has no command inventory")
  }
  let coordinates : Map[String, String] = Map([])
  for command in commands {
    guard command
      is {
        "name": String(name),
        "package_name": String(package_name),
        "version": String(version),
        "published": True,
        ..
      } &&
      package_name == "cli/" + name &&
      version != "" &&
      !coordinates.contains(name) else {
      fail("invalid frozen coordinate owner")
    }
    coordinates[name] = package_name + "@" + version
  }
  let candidates = metadata_paths.filter(ci_frozen_publication_metadata_path)
  let profile_values : Array[Json] = []
  for path in profiles {
    profile_values.push(@json.parse(@fs.read_file(path).text()))
  }
  let failures : Array[String] = []
  let reports : Array[String] = []
  let run_ids : Array[String] = []
  let mut row_count = 0
  if candidates.length() != 1 {
    failures.push(
      "frozen publication requires exactly one Linux published report",
    )
  }
  for path in candidates {
    let metadata : AuditRunMetadata = parse_json_file(path)
    failures.append(
      validate_metadata(
        metadata,
        binding.registry_hash,
        [binding.corpus_hash],
        [binding.manifest_hash],
        head,
      ),
    )
    let report_path = @path.Path(path)
      .dirname()
      .join(Path("summary.jsonl"))
      .normalize()
      .to_string()
    let rows = load_evidence_rows(report_path)
    row_count += rows.length()
    reports.push(report_path)
    run_ids.push(metadata.run_id)
    let bundle : EvidenceBundle = {
      report_path,
      metadata,
      rows,
      selected_ids: cases.map(fixture => fixture.id),
      published_coordinates: binding.coordinates,
      oracle_verified: profile_values.any(profile => {
        profile_matches(profile, metadata)
      }),
    }
    failures.append(
      ci_frozen_publication_errors(
        binding, registry, cases, coordinates, bundle,
      ),
    )
  }
  {
    status: if failures.is_empty() {
      "passed"
    } else {
      "failed"
    },
    required_case_ids: sorted_unique(cases.map(fixture => fixture.id)),
    required_coordinates: sorted_unique(binding.coordinates.copy()),
    observed_row_count: row_count,
    report_paths: sorted_unique(reports),
    run_ids: sorted_unique(run_ids),
    findings: failures.map(problem => "frozen publication: " + problem),
  }
}

///|
async fn ci_frozen_selected_ids(
  binding : CiFrozenBinding,
  registry : @registry.Registry,
  root : String,
) -> Array[String] {
  let ids : Array[String] = []
  for fixture in @testkit.load_cases(binding.corpus_path) {
    if @registry.validate_selected_cases(registry, [fixture], root~).is_empty() {
      ids.push(fixture.id)
    }
  }
  ids
}
