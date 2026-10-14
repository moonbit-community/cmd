///|
async fn[T : FromJson] parse_json_file(path : String) -> T {
  let value = @json.parse(@fs.read_file(path).text())
  @json.from_json(value)
}

///|
async fn resolve_revision(reference : String) -> String {
  let result = @shell.Cmd("git", [
    "rev-parse",
    "--verify",
    "--end-of-options",
    reference + "^{commit}",
  ]).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("cannot resolve Git revision: " + reference)
  }
  result.stdout().trim().to_owned()
}

///|
async fn git_changed_paths(base : String, head : String) -> Array[String] {
  let result = @shell.Cmd("git", [
    "diff", "--name-only", "--no-renames", "-z", base, head, "--",
  ]).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("git diff failed: " + result.stderr())
  }
  result
  .stdout()
  .split("\u0000")
  .filter(item => item != "")
  .map(item => item.to_owned())
  .collect()
}

///|
async fn selected_manifest_cases(
  path : String,
  depth~ : Int32 = 0,
) -> Array[@testkit.Case] {
  guard depth < 16 else {
    fail("manifest base cycle or excessive nesting: " + path)
  }
  let value = @json.parse(@fs.read_file(path).text())
  if value is { "base_manifest": String(base), "case_ids": Array(ids), .. } {
    let base_path = @path.Path(path)
      .dirname()
      .join(Path(base))
      .normalize()
      .to_string()
    let cases = selected_manifest_cases(base_path, depth=depth + 1)
    let extras : Array[@testkit.Case] = if value is { "extra_cases": extra, .. } {
      @json.from_json(extra)
    } else {
      []
    }
    let all = cases + extras
    let requested : Array[String] = @json.from_json(Json::array(ids))
    if requested.is_empty() {
      return all
    }
    // Release extra cases are unconditional. Explicit IDs add matching base
    // cases in request order and may use a registered historical alias.
    let selected = extras.copy()
    let included : Set[String] = Set::from_array(extras.map(item => item.id))
    for id in requested {
      if !all.any(item => {
          item.id == id || item.aliases.unwrap_or([]).contains(id)
        }) {
        fail("manifest selects unknown case: " + id)
      }
      for item in all {
        if (item.id == id || item.aliases.unwrap_or([]).contains(id)) &&
          !included.contains(item.id) {
          selected.push(item)
          included.add(item.id)
        }
      }
    }
    return selected
  }
  @testkit.load_cases(path)
}

///|
async fn load_evidence_rows(path : String) -> Array[EvidenceRow] {
  let rows : Array[EvidenceRow] = []
  for line in @fs.read_file(path).text().split("\n") {
    if line.trim() != "" {
      rows.push(@json.from_json(@json.parse(line)))
    }
  }
  rows
}

///|
async fn manifest_coordinates(path : String) -> Array[String] {
  let value = @json.parse(@fs.read_file(path).text())
  let result : Array[String] = []
  if value is { "commands": Array(commands), .. } {
    for command in commands {
      if command
        is {
          "name": String(name),
          "package_name": String(package_name),
          "version": String(version),
          ..
        } {
        guard package_name == "cli/" + name && version != "" else {
          fail("invalid manifest coordinate")
        }
        result.push(package_name + "@" + version)
      }
    }
  }
  result
}

///|
fn profile_matches(value : Json, metadata : AuditRunMetadata) -> Bool {
  let profile : @testkit.OracleProfile = @json.from_json(value) catch {
    _ => return false
  }
  @testkit.oracle_profile_errors(profile).is_empty() &&
  profile.id == metadata.oracle_profile_id &&
  profile.image_digest == metadata.oracle_image_digest &&
  profile.versions_sha256 == metadata.oracle_versions_hash
}

///|
pub async fn audit(options : AuditOptions) -> AuditReport {
  ignore(@async.platform)
  let root_result = @shell.Cmd("git", ["rev-parse", "--show-toplevel"]).output(
    timeout_ms=15000,
  )
  guard root_result.exit_code() == 0 else {
    fail("cannot resolve audited repository root")
  }
  let root = root_result.stdout().trim().to_owned()
  let base = resolve_revision(options.base)
  let head = resolve_revision(options.head)
  let paths = git_changed_paths(base, head)
  let declaration : ChangeDeclaration = parse_json_file(
    options.declaration_path,
  )
  let registry = @registry.load(options.registry_path)
  let failures = validate_declaration_shape(declaration)
  if resolve_revision("HEAD") != head {
    failures.push("source: checked-out HEAD must equal the audited head")
  }
  let source_state = @shell.Cmd("git", [
    "status", "--porcelain=v1", "--untracked-files=normal",
  ]).output(timeout_ms=15000)
  if source_state.exit_code() != 0 {
    fail("cannot inspect audited source state")
  }
  if source_state.stdout().trim() != "" {
    failures.push(
      "source: audit requires a clean checkout; keep report outputs ignored or outside the repository",
    )
  }
  failures.append(@registry.validate(registry))
  failures.append(@registry.validate_source_bindings(registry, root~))
  let registered_source_ids : Array[String] = []
  for source in @registry.case_sources(registry) {
    registered_source_ids.append(
      @testkit.load_cases(root + "/" + source).map(item => item.id),
    )
  }
  failures.append(
    @registry.validate_case_bindings(registry, registered_source_ids),
  )
  let (_, core_changed, scope_failures) = validate_changed_scope(
    paths, declaration, registry,
  )
  failures.append(scope_failures)
  failures.append(validate_coverage(declaration, registry))
  failures.append(validate_boundaries(declaration, registry))
  let registry_hash = @testkit.manifest_digest(options.registry_path)
  let corpus_hashes : Array[String] = []
  let corpus_ids : Array[String] = []
  for path in options.case_corpus_paths {
    let cases = @testkit.load_cases(path)
    failures.append(@registry.validate_selected_cases(registry, cases, root~))
    let hash = @testkit.manifest_digest(path)
    if hash == "" {
      failures.push("corpus: cannot fingerprint " + path)
    }
    corpus_hashes.push(hash)
    corpus_ids.append(cases.map(item => item.id))
  }
  let manifest_hashes : Array[String] = []
  let selections : Map[String, Array[String]] = Map([])
  let coordinates : Map[String, Array[String]] = Map([])
  for path in options.manifest_paths {
    let cases = selected_manifest_cases(path)
    failures.append(@registry.validate_selected_cases(registry, cases, root~))
    let hash = @testkit.manifest_digest(path)
    if hash == "" {
      failures.push("manifest: cannot fingerprint " + path)
    }
    manifest_hashes.push(hash)
    selections[hash] = cases.map(item => item.id)
    coordinates[hash] = manifest_coordinates(path)
  }
  for id in declaration.case_ids.unwrap_or([]) {
    if !corpus_ids.contains(id) &&
      !selections.values().any(ids => ids.contains(id)) {
      failures.push("coverage: declared updated case does not exist '\{id}'")
    }
  }
  let run_ids : Map[String, Bool] = Map([])
  let bundles : Array[EvidenceBundle] = []
  let profiles : Array[Json] = []
  for path in options.oracle_profile_paths {
    profiles.push(@json.parse(@fs.read_file(path).text()))
  }
  for metadata_path in options.run_metadata_paths {
    let metadata : AuditRunMetadata = parse_json_file(metadata_path)
    if run_ids.contains(metadata.run_id) {
      failures.push("metadata: duplicate run_id " + metadata.run_id)
    }
    run_ids[metadata.run_id] = true
    for
      problem in validate_metadata(
        metadata, registry_hash, corpus_hashes, manifest_hashes, head,
      ) {
      failures.push(metadata.run_id + ": " + problem)
    }
    let report_path = @path.Path(metadata_path)
      .dirname()
      .join(Path("summary.jsonl"))
      .normalize()
      .to_string()
    bundles.push({
      report_path,
      metadata,
      rows: load_evidence_rows(report_path),
      selected_ids: selections.get(metadata.manifest_hash).unwrap_or([]),
      oracle_verified: profiles.any(profile => {
        profile_matches(profile, metadata)
      }),
      published_coordinates: coordinates
      .get(metadata.manifest_hash)
      .unwrap_or([]),
    })
  }
  failures.append(validate_report_evidence(declaration, registry, bundles))
  let affected = canonical_ids(registry, declaration.affected_behaviors)
  let unsupported = affected.filter(id => {
    find_entry(registry, id) is Some(entry) && entry.status == "unsupported"
  })
  let boundary = affected.filter(id => {
    find_entry(registry, id) is Some(entry) && entry.status == "boundary"
  })
  let uncovered = affected.filter(id => {
    let individual = {
      ..declaration,
      affected_behaviors: [id],
      coverage: declaration.coverage.filter(record => {
        find_entry(registry, record.behavior_id) is Some(entry) &&
        entry.behavior_id == id
      }),
    }
    !validate_coverage(individual, registry).is_empty() ||
    !validate_report_evidence(individual, registry, bundles).is_empty()
  })
  uncovered.append(declaration.uncovered.unwrap_or([]))
  {
    base,
    head,
    changed_paths: paths,
    affected_commands: sorted_unique(declaration.affected_commands.copy()),
    core_changed,
    status: if failures.is_empty() {
      "passed"
    } else {
      "failed"
    },
    findings: failures,
    run_ids: sorted_unique(run_ids.keys().collect()),
    uncovered: sorted_unique(uncovered),
    unsupported,
    boundary,
    deferred: canonical_ids(registry, declaration.deferred),
  }
}

///|
fn report_text(report : AuditReport) -> String {
  let out = StringBuilder()
  out.write("# Coverage audit\n\n")
  out.write(
    "- Base: `\{report.base}`\n- Head: `\{report.head}`\n- Status: `\{report.status}`\n",
  )
  out.write("- Core change: `\{report.core_changed}`\n")
  out.write(
    "- Affected commands: " + report.affected_commands.join(", ") + "\n",
  )
  out.write("- Runs: " + report.run_ids.join(", ") + "\n")
  for
    (label, values) in [
      ("Uncovered", report.uncovered),
      ("Unsupported", report.unsupported),
      ("Boundary", report.boundary),
      ("Deferred", report.deferred),
      ("Changed paths", report.changed_paths),
      ("Findings", report.findings),
    ] {
    out.write("\n## " + label + "\n\n")
    if values.is_empty() {
      out.write("None.\n")
    }
    for value in values {
      out.write("- " + value + "\n")
    }
  }
  out.to_string()
}

///|
fn parse_arguments(
  args : ArrayView[String],
) -> Map[String, Array[String]] raise Failure {
  let values : Map[String, Array[String]] = Map([])
  guard args.length() % 2 == 0 else {
    fail("every audit option requires a value")
  }
  let allowed = [
    "--base", "--head", "--declaration", "--run-metadata", "--registry", "--case-corpus",
    "--manifest", "--oracle-profile", "--report",
  ]
  for index = 0; index < args.length(); index = index + 2 {
    let name = args[index]
    guard allowed.contains(name) else { fail("unknown audit option: " + name) }
    guard args[index + 1].trim() != "" else {
      fail("empty audit option: " + name)
    }
    let group = values.get(name).unwrap_or([])
    if !["--run-metadata", "--manifest", "--case-corpus", "--oracle-profile"].contains(
        name,
      ) &&
      !group.is_empty() {
      fail("duplicate audit option: " + name)
    }
    group.push(args[index + 1])
    values[name] = group
  }
  for name in ["--base", "--head", "--declaration", "--run-metadata"] {
    guard values.contains(name) else { fail("required audit option: " + name) }
  }
  values
}

///|
pub async fn run(args : Array[String]) -> Unit {
  let values = parse_arguments(args) catch {
    error => {
      @stdio.stderr.write("\{error}\n")
      @sys.exit(2)
      return
    }
  }
  let options : AuditOptions = {
    base: values["--base"][0],
    head: values["--head"][0],
    declaration_path: values["--declaration"][0],
    run_metadata_paths: values["--run-metadata"],
    registry_path: values
    .get("--registry")
    .unwrap_or(["tests/registry/registry.json"])[0],
    case_corpus_paths: values
    .get("--case-corpus")
    .unwrap_or(["tests/fixtures/runner/cases.json"]),
    manifest_paths: values
    .get("--manifest")
    .unwrap_or(["tests/fixtures/runner/cases.json"]),
    oracle_profile_paths: values
    .get("--oracle-profile")
    .unwrap_or(["tests/runner/image/profile.json"]),
    report_path: values.get("--report").map(items => items[0]),
  }
  let report = audit(options) catch {
    error => {
      @stdio.stderr.write("coverage audit infrastructure: \{error}\n")
      @sys.exit(2)
      return
    }
  }
  match options.report_path {
    Some(path) => {
      @fs.write_file(path, report_text(report))
      @fs.write_file(
        path + ".json",
        @testkit.canonical_json(ToJson::to_json(report)),
      )
    }
    None => println(report_text(report))
  }
  if report.status != "passed" {
    @sys.exit(1)
  }
}
