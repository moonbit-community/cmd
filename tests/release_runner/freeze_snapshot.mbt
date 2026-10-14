///|
priv struct FrozenSource {
  path : String
  sha256 : String
} derive(FromJson, ToJson)

///|
priv struct FrozenProvenance {
  schema : Int32
  kind : String
  source_revision : String
  source_manifest_path : String
  source_manifest_sha256 : String
  source_base_path : String
  manifest_sha256 : String
  corpus_sha256 : String
  registry_sha256 : String
  source_registry_path : String?
  sources : Array[FrozenSource]
  interpretation : String
} derive(FromJson, ToJson)

///|
async fn snapshot_git(root : String, args : Array[String]) -> Bytes {
  let result = @testkit.run("git", ["-C", root, ..args])
  guard result.status == 0 else {
    fail(
      "cannot recover immutable Git snapshot: " + @utf8.decode(result.stderr),
    )
  }
  result.stdout
}

///|
async fn snapshot_source(
  root : String,
  revision : String,
  path : String,
) -> Bytes {
  guard @testkit.safe_relative_path(path) else {
    fail("unsafe Git snapshot path")
  }
  snapshot_git(root, ["show", revision + ":" + path])
}

///|
fn snapshot_child(parent : String, child : String) -> String raise Failure {
  let path = @path.Path(parent)
    .dirname()
    .join(Path(child))
    .normalize()
    .to_string()
  guard @testkit.safe_relative_path(path) else {
    fail("snapshot corpus escapes repository")
  }
  path
}

///|
async fn snapshot_cases(
  root : String,
  revision : String,
  path : String,
  sources : Array[(String, Bytes)],
) -> Array[ReleaseCase] {
  snapshot_cases_with(path, sources, [], source => {
    snapshot_source(root, revision, source)
  })
}

///|
/// Resolve nested indexes from one immutable source revision. The injected
/// reader lets regressions exercise cycles and overrides without a Git write.
async fn snapshot_cases_with(
  path : String,
  sources : Array[(String, Bytes)],
  ancestors : Array[String],
  read_source : async (String) -> Bytes,
) -> Array[ReleaseCase] {
  guard !ancestors.contains(path) else {
    fail("snapshot corpus reference cycle: " + path)
  }
  let bytes = read_source(path)
  if !sources.any(source => source.0 == path) {
    sources.push((path, bytes))
  }
  let ancestors = ancestors + [path]
  let value = @json.parse(@utf8.decode(bytes))
  let cases : Array[ReleaseCase] = match value {
    { "cases": cases, .. } => @json.from_json(cases)
    _ => []
  }
  if value is { "case_files": Array(files), .. } {
    for file in files {
      guard file is String(file) else {
        fail("snapshot case file must be a path")
      }
      let child = snapshot_child(path, file)
      cases.append(snapshot_cases_with(child, sources, ancestors, read_source))
    }
  }
  if value is { "case_overrides": Array(files), .. } {
    let overridden : Set[String] = Set([])
    for file in files {
      guard file is String(file) else {
        fail("snapshot override must be a path")
      }
      let child = snapshot_child(path, file)
      let selected = snapshot_cases_with(child, sources, ancestors, read_source)
      for replacement in selected {
        guard !overridden.contains(replacement.id) else {
          fail("duplicate snapshot override")
        }
        let mut found = false
        for index, current in cases {
          if current.id == replacement.id {
            guard current.command == replacement.command else {
              fail("snapshot override changes command")
            }
            cases[index] = replacement
            found = true
            break
          }
        }
        guard found else { fail("snapshot override references unknown case") }
        overridden.add(replacement.id)
      }
    }
  }
  let ids : Set[String] = Set([])
  for fixture in cases {
    for id in [fixture.id, ..fixture.aliases.unwrap_or([])] {
      guard !ids.contains(id) else { fail("snapshot duplicate case identity") }
      ids.add(id)
    }
  }
  cases
}

///|
fn snapshot_corpus_bytes(cases : Array[ReleaseCase]) -> Bytes {
  let corpus : ActiveCasesIndex = {
    schema: 2,
    cases,
    case_files: [],
    case_overrides: [],
  }
  @utf8.encode(@testkit.canonical_json(ToJson::to_json(corpus)) + "\n")
}

///|
async fn migration_baseline(root : String) -> String {
  let baseline = @json.parse(
    @fs.read_file(root + "/tests/registry/baseline.json").text(),
  )
  guard baseline is { "git_revision": String(revision), .. } else {
    fail("migration baseline has no Git revision")
  }
  revision
}

///|
async fn historical_source_revision(
  root : String,
  baseline : String,
  source : String,
) -> String {
  let revision = @utf8.decode(
      snapshot_git(root, ["log", "-1", "--format=%H", baseline, "--", source]),
    )
    .trim()
    .to_owned()
  guard revision != "" else {
    fail("no recorded Git source for historical manifest: " + source)
  }
  revision
}

///|
async fn write_snapshot_sidecars(
  root : String,
  manifest_path : String,
  source_manifest_path : String,
  source_revision : String,
  source_base_path : String,
  kind : String,
  registry_path : String,
) -> Unit {
  let original_manifest = snapshot_source(
    root, source_revision, source_manifest_path,
  )
  let sources : Array[(String, Bytes)] = []
  let cases = snapshot_cases(root, source_revision, source_base_path, sources)
  sources.sort_by((left, right) => left.0.lexical_compare(right.0))
  let corpus = snapshot_corpus_bytes(cases)
  let registry = @fs.read_file(registry_path).binary()
  let provenance : FrozenProvenance = {
    schema: 1,
    kind,
    source_revision,
    source_manifest_path,
    source_base_path,
    source_manifest_sha256: @testkit.sha256_bytes(original_manifest),
    manifest_sha256: @testkit.file_digest(manifest_path),
    corpus_sha256: @testkit.sha256_bytes(corpus),
    registry_sha256: @testkit.sha256_bytes(registry),
    source_registry_path: None,
    sources: sources.map(source => {
      path: source.0,
      sha256: @testkit.sha256_bytes(source.1),
    }),
    interpretation: "Source snapshot only. This migration preserves recoverable Git input, not historical execution or compatibility acceptance. Registry attachment records migration ownership only.",
  }
  write_immutable(manifest_path + ".cases.json", corpus)
  write_immutable(manifest_path + ".registry.json", registry)
  @fs.mkdir(manifest_path + ".sources", recursive=true, allow_exist=true)
  for (path, bytes) in sources {
    ignore(path)
    write_immutable(
      manifest_path + ".sources/" + @testkit.sha256_bytes(bytes) + ".json",
      bytes,
    )
  }
  write_immutable(
    manifest_path + ".provenance.json",
    @utf8.encode(@testkit.canonical_json(ToJson::to_json(provenance)) + "\n"),
  )
}

///|
/// Read-only replay validation re-derives the corpus from recorded Git bytes.
/// A self-consistent set of locally authored hashes cannot authorize a new
/// published contract. Frozen registry ownership and the currently reviewed
/// oracle recipe govern any new differential execution separately.
async fn validate_frozen_case_binding(
  root : String,
  manifest_path : String,
  base_path : String,
) -> Array[String] {
  try {
    validate_frozen_case_binding_checked(root, manifest_path, base_path)
    []
  } catch {
    error => ["frozen replay provenance invalid: " + error.to_string()]
  }
}

///|
async fn validate_frozen_case_binding_checked(
  root : String,
  manifest_path : String,
  base_path : String,
) -> Unit {
  let root = @fs.realpath(root)
  let actual = @fs.realpath(manifest_path)
  let relative = @path.Path(actual).relative(base=Path(root)).to_string()
  let current = relative == "tests/release_runner/current/published.json"
  guard current ||
    (
      relative.has_prefix("tests/release_runner/historical/published-") &&
      relative.has_suffix(".json")
    ) else {
    fail("unrecognized frozen manifest location")
  }
  guard @fs.realpath(base_path) == @fs.realpath(actual + ".cases.json") else {
    fail("replay must use immutable resolved corpus")
  }
  let provenance : FrozenProvenance = @json.from_json(
    @json.parse(@fs.read_file(actual + ".provenance.json").text()),
  )
  guard provenance.schema == 1 &&
    provenance.manifest_sha256 == @testkit.file_digest(actual) &&
    provenance.corpus_sha256 == @testkit.file_digest(base_path) &&
    provenance.registry_sha256 ==
    @testkit.file_digest(actual + ".registry.json") else {
    fail("frozen snapshot hash mismatch")
  }
  if provenance.kind == "verified-publication" {
    validate_verified_publication(root, actual, base_path, provenance)
    return
  }
  let baseline = migration_baseline(root)
  let migration_current = provenance.kind == "migration-current-source"
  let source = if migration_current {
    "tests/release_runner/published-2026-10-11-repair.json"
  } else {
    "tests/release_runner/" + @path.Path(relative).basename().to_owned()
  }
  let revision = if migration_current {
    baseline
  } else {
    historical_source_revision(root, baseline, source)
  }
  guard provenance.source_revision == revision &&
    provenance.source_manifest_path == source &&
    provenance.kind ==
    (if migration_current {
      "migration-current-source"
    } else {
      "historical-git-source"
    }) else {
    fail("frozen snapshot source revision mismatch")
  }
  let original = snapshot_source(root, revision, source)
  guard @testkit.sha256_bytes(original) == provenance.source_manifest_sha256 else {
    fail("frozen source manifest mismatch")
  }
  let original_value = @json.parse(@utf8.decode(original))
  let current_value = @json.parse(@fs.read_file(actual).text())
  if migration_current {
    guard original_value is Object(expected) &&
      current_value is Object(observed) else {
      fail("invalid current manifest object")
    }
    let expected = expected.copy()
    expected["base_manifest"] = "published-cases.json"
    expected["core_version"] = "0.5.0"
    guard @testkit.canonical_json(Json(expected)) ==
      @testkit.canonical_json(Json(observed)) else {
      fail("current published manifest differs from frozen migration source")
    }
  } else {
    guard original == @fs.read_file(actual).binary() else {
      fail("historical manifest bytes differ from Git source")
    }
  }
  guard original_value is { "base_manifest": String(base), .. } else {
    fail("historical helper document is not an executable release manifest")
  }
  let source_base = snapshot_child(source, base)
  guard source_base == provenance.source_base_path else {
    fail("frozen corpus source path mismatch")
  }
  let sources : Array[(String, Bytes)] = []
  let cases = snapshot_cases(root, revision, source_base, sources)
  guard snapshot_corpus_bytes(cases) == @fs.read_file(base_path).binary() else {
    fail("frozen corpus differs from recorded Git source")
  }
  guard sources.length() == provenance.sources.length() else {
    fail("frozen source inventory length mismatch")
  }
  for (path, bytes) in sources {
    let digest = @testkit.sha256_bytes(bytes)
    guard provenance.sources.any(source => {
        source.path == path && source.sha256 == digest
      }) &&
      @fs.read_file(actual + ".sources/" + digest + ".json").binary() == bytes else {
      fail("frozen source archive mismatch")
    }
  }
}

///|
fn frozen_publication(candidate : ReleaseManifest) -> ReleaseManifest {
  {
    ..candidate,
    candidate: Some(false),
    base_manifest: "published-cases.json",
    commands: candidate.commands.map(row => { ..row, published: true, }),
    case_ids: [],
    extra_cases: [],
  }
}

///|
async fn validate_verified_publication(
  root : String,
  manifest_path : String,
  corpus_path : String,
  provenance : FrozenProvenance,
) -> Unit {
  guard provenance.source_registry_path is Some(registry_path) else {
    fail("verified publication missing source registry")
  }
  let revision = provenance.source_revision
  let candidate_bytes = snapshot_source(
    root,
    revision,
    provenance.source_manifest_path,
  )
  guard @testkit.sha256_bytes(candidate_bytes) ==
    provenance.source_manifest_sha256 else {
    fail("verified candidate source checksum mismatch")
  }
  let candidate : ReleaseManifest = @json.from_json(
    @json.parse(@utf8.decode(candidate_bytes)),
  )
  guard candidate.candidate == Some(true) &&
    candidate.commands.all(row => !row.published) else {
    fail("verified publication source is not an unpublished candidate")
  }
  let source_base = snapshot_child(
    provenance.source_manifest_path,
    candidate.base_manifest,
  )
  guard source_base == provenance.source_base_path else {
    fail("verified candidate corpus source mismatch")
  }
  let sources : Array[(String, Bytes)] = []
  let cases = snapshot_cases(root, revision, source_base, sources)
  let selected = selected_cases(candidate, { schema: 2, cases, })
  guard snapshot_corpus_bytes(selected) == @fs.read_file(corpus_path).binary() else {
    fail("verified publication corpus differs from committed candidate")
  }
  let expected = @testkit.canonical_json(
    ToJson::to_json(frozen_publication(candidate)),
  )
  let actual = @testkit.canonical_json(
    @json.parse(@fs.read_file(manifest_path).text()),
  )
  guard actual == expected else {
    fail("published manifest differs from committed candidate transformation")
  }
  let registry_bytes = snapshot_source(root, revision, registry_path)
  guard registry_bytes ==
    @fs.read_file(manifest_path + ".registry.json").binary() else {
    fail("verified publication registry differs from committed source")
  }
  guard sources.length() == provenance.sources.length() else {
    fail("verified publication source inventory length mismatch")
  }
  for (path, bytes) in sources {
    let digest = @testkit.sha256_bytes(bytes)
    guard provenance.sources.any(source => {
        source.path == path && source.sha256 == digest
      }) &&
      @fs.read_file(manifest_path + ".sources/" + digest + ".json").binary() ==
      bytes else {
      fail("verified publication source archive mismatch")
    }
  }
}

///|
async fn copy_snapshot_sidecars(source : String, destination : String) -> Unit {
  for suffix in [".cases.json", ".registry.json", ".provenance.json"] {
    write_immutable(
      destination + suffix,
      @fs.read_file(source + suffix).binary(),
    )
  }
  @fs.mkdir(destination + ".sources", recursive=true, allow_exist=true)
  for name in @fs.readdir(source + ".sources", sort=true) {
    write_immutable(
      destination + ".sources/" + name,
      @fs.read_file(source + ".sources/" + name).binary(),
    )
  }
}

///|
async fn prepare_current_snapshot(
  root : String,
  candidate_path : String,
  registry_path : String,
  revision : String,
  published_bytes : Bytes,
  selected : Array[ReleaseCase],
) -> (Array[(String, Bytes)], Array[(String, Bytes)]) {
  let candidate_source = @path.Path(@fs.realpath(candidate_path))
    .relative(base=Path(@fs.realpath(root)))
    .to_string()
  let registry_source = @path.Path(@fs.realpath(registry_path))
    .relative(base=Path(@fs.realpath(root)))
    .to_string()
  let candidate_bytes = snapshot_source(root, revision, candidate_source)
  guard candidate_bytes == @fs.read_file(candidate_path).binary() else {
    fail("freeze candidate is not the committed evidence revision")
  }
  let registry_bytes = snapshot_source(root, revision, registry_source)
  guard registry_bytes == @fs.read_file(registry_path).binary() else {
    fail("freeze registry is not the committed evidence revision")
  }
  let candidate : ReleaseManifest = @json.from_json(
    @json.parse(@utf8.decode(candidate_bytes)),
  )
  let source_base = snapshot_child(candidate_source, candidate.base_manifest)
  let sources : Array[(String, Bytes)] = []
  let base_cases = snapshot_cases(root, revision, source_base, sources)
  let expected_cases = selected_cases(candidate, {
    schema: 2,
    cases: base_cases,
  })
  let corpus = snapshot_corpus_bytes(selected)
  guard corpus == snapshot_corpus_bytes(expected_cases) else {
    fail("freeze cases are not the committed evidence revision")
  }
  sources.sort_by((left, right) => left.0.lexical_compare(right.0))
  let provenance : FrozenProvenance = {
    schema: 1,
    kind: "verified-publication",
    source_revision: revision,
    source_manifest_path: candidate_source,
    source_manifest_sha256: @testkit.sha256_bytes(candidate_bytes),
    source_base_path: source_base,
    source_registry_path: Some(registry_source),
    manifest_sha256: @testkit.sha256_bytes(published_bytes),
    corpus_sha256: @testkit.sha256_bytes(corpus),
    registry_sha256: @testkit.sha256_bytes(registry_bytes),
    sources: sources.map(source => {
      path: source.0,
      sha256: @testkit.sha256_bytes(source.1),
    }),
    interpretation: "Frozen by the exact registry, MoonX contract, differential and reproducibility gates. Replaying these source bytes does not repeat historical acceptance.",
  }
  let outputs = [
    (".cases.json", corpus),
    (".registry.json", registry_bytes),
    (
      ".provenance.json",
      @utf8.encode(@testkit.canonical_json(ToJson::to_json(provenance)) + "\n"),
    ),
    ("", published_bytes),
  ]
  (sources, outputs)
}

///|
async fn replace_current_snapshot(
  current_manifest : String,
  snapshot : (Array[(String, Bytes)], Array[(String, Bytes)]),
) -> Unit {
  let (sources, outputs) = snapshot
  @fs.mkdir(current_manifest + ".sources", recursive=true, allow_exist=true)
  for (_, bytes) in sources {
    write_immutable(
      current_manifest + ".sources/" + @testkit.sha256_bytes(bytes) + ".json",
      bytes,
    )
  }
  for (suffix, bytes) in outputs {
    @fs.write_file(current_manifest + suffix + ".next", bytes)
  }
  // The manifest pointer is last; interrupted replacements fail closed until retried.
  for (suffix, _) in outputs {
    @fs.rename(
      current_manifest + suffix + ".next",
      current_manifest + suffix,
      replace=true,
    )
  }
}

///|
async fn migrate_historical_snapshots(
  root : String,
  baseline_revision : String,
  registry_path~ : String,
) -> Unit {
  let baseline = migration_baseline(root)
  guard baseline_revision == baseline else {
    fail("migration requires the frozen baseline revision")
  }
  let historical = root + "/tests/release_runner/historical"
  for name in @fs.readdir(historical, sort=true) {
    if !name.has_prefix("published-") ||
      !name.has_suffix(".json") ||
      name.contains(".cases.") ||
      name.contains(".provenance.") ||
      name.contains(".registry.") {
      continue
    }
    let path = historical + "/" + name
    let value = @json.parse(@fs.read_file(path).text())
    guard value is { "base_manifest": String(base), .. } else { continue }
    let source = "tests/release_runner/" + name
    let revision = historical_source_revision(root, baseline, source)
    guard snapshot_source(root, revision, source) ==
      @fs.read_file(path).binary() else {
      fail("historical manifest changed during migration: " + name)
    }
    write_snapshot_sidecars(
      root,
      path,
      source,
      revision,
      snapshot_child(source, base),
      "historical-git-source",
      registry_path,
    )
  }
  write_snapshot_sidecars(
    root,
    root + "/tests/release_runner/current/published.json",
    "tests/release_runner/published-2026-10-11-repair.json",
    baseline,
    "tests/release_runner/active-cases.json",
    "migration-current-source",
    registry_path,
  )
}
