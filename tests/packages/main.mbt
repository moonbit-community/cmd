///|
async fn main {
  @testkit.begin_environment_capture()
  let args = @env.args()[1:]
  if args.contains("--help") {
    println(
      "Usage: packages --backend native|wasm|pair (--all | --case stable-id | --package path) [--report-dir path]",
    )
    return
  }
  let started = @async.now()
  let mut backend = "native"
  let mut case_id = ""
  let mut package_path = ""
  let mut directory = ""
  let mut all = false
  let mut index = 0
  while index < args.length() {
    if args[index] == "--all" {
      all = true
      index += 1
      continue
    }
    guard args.get(index + 1) is Some(value) else {
      fail("option requires a value: " + args[index])
    }
    match args[index] {
      "--backend" => backend = value
      "--case" => case_id = value
      "--package" => package_path = @path.Path(value).normalize().to_string()
      "--report-dir" => directory = value
      _ => fail("unknown option: " + args[index])
    }
    index += 2
  }
  guard ["native", "wasm", "pair"].contains(backend) else {
    fail("expected native, wasm or pair backend")
  }
  let selectors = (if all { 1 } else { 0 }) +
    (if case_id != "" { 1 } else { 0 }) +
    (if package_path != "" { 1 } else { 0 })
  guard selectors == 1 else {
    fail("select exactly one --all, --case or --package")
  }
  let registry_path = "tests/registry/registry.json"
  let registry = @registry.load(registry_path)
  let errors = @registry.validate(registry)
  errors.append(@registry.validate_source_bindings(registry))
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let selected = registry.entries.filter(entry => {
    let source = entry.source.split("::").collect()[0].to_owned()
    entry.implementation == "package-test" &&
    (
      (
        all &&
        platform_applies(entry.platforms, @testkit.host_platform()) &&
        (if backend == "pair" {
          entry.requires_backend_pair()
        } else {
          entry.required_backends.contains(backend)
        })
      ) ||
      entry.behavior_id == case_id ||
      entry.aliases.contains(case_id) ||
      (package_path != "" && package_selected(source, package_path))
    )
  })
  selected.sort_by_key(entry => entry.behavior_id)
  guard !selected.is_empty() else {
    fail("selection has no registered package tests")
  }
  if directory == "" {
    directory = "test-reports/packages-" + backend + "-" + started.to_string()
  }
  guard !@fs.exists(directory) else {
    fail("report directory already exists: " + directory)
  }
  @fs.mkdir(directory, recursive=true)
  let corpus_path = directory + "/source-corpus.json"
  let corpus = @testkit.canonical_json(source_corpus())
  @fs.write_file(corpus_path, corpus)
  let start_metadata = @testkit.collect_run_metadata(
    "packages-" + backend + "-" + started.to_string(),
    manifest_path=registry_path,
    registry_path~,
    case_corpus_path=corpus_path,
    oracle_profile_id="",
    started_at_ms=started,
    ended_at_ms=started,
  )
  let reports : Array[@testkit.CaseReport] = []
  for entry in selected {
    if backend == "pair" {
      reports.append(execute_package_pair(entry, directory))
    } else {
      reports.push(execute_package_test(entry, backend, directory))
    }
  }
  let stable = @testkit.canonical_json(source_corpus()) == corpus
  if !stable {
    for index, row in reports {
      reports[index] = {
        ..row,
        result: "infra",
        stage: "source-stability",
        detail: "workspace source corpus changed during execution",
        observations: [],
        missing_observations: [..row.observations, ..row.missing_observations],
      }
    }
  }
  let metadata = @testkit.collect_run_metadata(
    "packages-" + backend + "-" + started.to_string(),
    manifest_path=registry_path,
    registry_path~,
    case_corpus_path=corpus_path,
    native_root=directory + "/artifacts/native",
    wasm_root=directory + "/artifacts/wasm",
    oracle_profile_id="",
    started_at_ms=started,
    ended_at_ms=@async.now(),
  )
  // Test artifacts are built during this run. Each executed test already
  // checks its index and artifact against the frozen captured bytes. Adopt
  // only those artifact hashes; keep all run-start source/policy/host fields.
  let start_metadata = {
    ..start_metadata,
    native_artifact_hash: metadata.native_artifact_hash,
    wasm_artifact_hash: metadata.wasm_artifact_hash,
  }
  let metadata = @testkit.finalize_run_metadata(start_metadata, metadata)
  let metadata = if stable {
    metadata
  } else {
    { ..metadata, reproducibility_status: "changed-during-run", }
  }
  @testkit.write_reports_with_metadata(directory, reports, metadata)
  let failed = reports.filter(row => row.result != "pass")
  for row in failed {
    println(row.id + ": " + row.result + " / " + row.detail)
  }
  println(
    "package tests (\{backend}): \{reports.length() - failed.length()}/\{reports.length()} passed; report: \{directory}",
  )
  if !failed.is_empty() || metadata.reproducibility_status != "complete" {
    @sys.exit(1)
  }
}
