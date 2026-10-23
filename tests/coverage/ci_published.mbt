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
async fn ci_published_enabled(context : CiContext) -> Bool {
  if context.base == "" {
    ignore(ci_scope_preflight(context))
    return true
  }
  guard ci_scope_preflight(context) is Some(intent) else {
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
  let published = ci_published_enabled(context)
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
  !metadata.moonx_coordinates.is_empty() &&
  metadata.moonx_coordinates.all(coordinate => {
    binding.coordinates.contains(coordinate)
  })
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
