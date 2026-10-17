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
  if context.event == "schedule" || context.event == "workflow_dispatch" {
    return true
  }
  let paths = git_changed_paths(context.base, context.head)
  if !paths.is_empty() && paths.all(ci_documentation_path) {
    return false
  }
  ci_impact_needs_published(
    ci_impact(
      @json.parse(@fs.read_file("tests/coverage/ci-change.json").text()),
    ),
    @registry.load("tests/registry/registry.json"),
  )
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
