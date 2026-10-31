///|
async fn proof_load_cases(index : @registry.Registry) -> Array[@testkit.Case] {
  let sources : Set[String] = Set([])
  let cases : Array[@testkit.Case] = []
  for entry in index.entries {
    if entry.is_case() && !sources.contains(entry.source) {
      sources.add(entry.source)
      cases.append(@testkit.load_cases(entry.source))
    }
  }
  cases
}

///|
async fn main {
  let args = @env.args()[1:]
  if args == ["--generate"] {
    generate_proof_obligations()
    return
  }
  if args.length() == 2 && args[0] == "--source-snapshot" {
    guard !@fs.exists(args[1]) else {
      fail("preserve previous test-source snapshot")
    }
    @fs.write_file(
      args[1],
      @testkit.scenario_contract_snapshot([]).stringify(indent=2) + "\n",
    )
    return
  }
  let options : Map[String, String] = Map([])
  for i = 0; i < args.length(); i = i + 2 {
    guard i + 1 < args.length() &&
      [
        "--manifest", "--reports", "--output", "--revision", "--started-after-ms",
        "--require-full", "--build-receipt",
      ].contains(args[i]) &&
      !options.contains(args[i]) else {
      fail(
        "Usage: proofs --reports FRESH_RUN --output FILE --started-after-ms START [--revision SHA] [--require-full true|false]",
      )
    }
    options[args[i]] = args[i + 1]
  }
  let manifest_text = @fs.read_file(
    options.get("--manifest").unwrap_or("tests/registry/coverage.json"),
  ).text()
  let manifest = @json.parse(manifest_text)
  let index = @registry.load("tests/registry/registry.json")
  let cases = proof_load_cases(index)
  let scenario_catalog = @json.parse(
    @fs.read_file("tests/registry/scenario-proofs.json").text(),
  )
  let catalog_errors = @testkit.scenario_catalog_errors(scenario_catalog)
  guard catalog_errors.is_empty() else { fail(catalog_errors.join("\n")) }
  let errors = proof_definitions_errors(
    manifest,
    index,
    cases,
    @contracts.command_catalog(),
    scenario_catalog~,
  )
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let directory = options.get("--reports").unwrap_or("")
  let output = options.get("--output").unwrap_or("")
  guard !directory.is_empty() && !output.is_empty() && !@fs.exists(output) else {
    fail("proof execution requires reports and a fresh output file")
  }
  let after = @string.parse_int64(
    options.get("--started-after-ms").unwrap_or("0"),
  )
  guard after > 0L else {
    fail(
      "actual proof requires the current controller's positive run-start time",
    )
  }
  let run = @json.parse(@fs.read_file(directory + "/run.json").text())
  let completed : Int64 = @json.from_json(proof_field(run, "completed_at_ms"))
  let revision = options
    .get("--revision")
    .unwrap_or(@env.get_env_var("GITHUB_SHA").unwrap_or("local"))
  guard completed >= after &&
    proof_field(run, "revision") == Json(revision) &&
    proof_field(run, "mode") == Json("wasm") else {
    fail(
      "stale or different-revision/backend execution cannot qualify current proofs",
    )
  }
  let text = @fs.read_file(directory + "/selected-cases.json").text()
  guard proof_field(run, "case_definitions_sha256") ==
    Json(@testkit.sha256_bytes(@utf8.encode(text))) else {
    fail("actual executed case definitions are missing or changed")
  }
  let snapshot = @json.parse(text)
  let build_path = options.get("--build-receipt").unwrap_or("")
  guard !build_path.is_empty() else {
    fail(
      "scenario proofs require the current controller's Native build receipt",
    )
  }
  let build = @json.parse(@fs.read_file(build_path).text())
  let build_errors = proof_build_errors(build, snapshot, completed, after)
  guard build_errors.is_empty() else { fail(build_errors.join("\n")) }
  let selected : Array[@testkit.Case] = @json.from_json(
    proof_field(snapshot, "cases"),
  )
  guard proof_field(snapshot, "metadata_contracts") ==
    @testkit.metadata_contract_snapshot(selected) else {
    fail(
      "current package versions or typed metadata assertions differ from the actual execution snapshot",
    )
  }
  guard proof_field(snapshot, "scenario_contracts") ==
    @testkit.scenario_contract_snapshot(selected) else {
    fail(
      "current scenario assertion descriptors or source inventory differ from actual execution",
    )
  }
  let scenario_text = @fs.read_file(directory + "/scenario-proofs.json").text()
  guard proof_field(run, "scenario_proofs_sha256") ==
    Json(@testkit.sha256_bytes(@utf8.encode(scenario_text))) else {
    fail("actual scenario assertion sidecar is missing or changed")
  }
  let scenario_receipts = @json.parse(scenario_text)
  let results : Array[Json] = []
  let results_text = @fs.read_file(directory + "/summary.jsonl").text()
  for line in results_text.split("\n") {
    if !line.is_empty() {
      results.push(@json.parse(line.to_owned()))
    }
  }
  let result_errors = proof_result_errors(
    run,
    results,
    @testkit.sha256_bytes(@utf8.encode(results_text)),
  )
  guard result_errors.is_empty() else { fail(result_errors.join("\n")) }
  let platform = proof_text(proof_field(run, "platform"))
  guard ["linux", "macos", "windows"].contains(platform) else {
    fail("unknown actual proof platform")
  }
  let report = join_proof_results(
    manifest,
    index,
    cases,
    selected,
    results,
    platform,
    scenario_catalog~,
    scenario_receipts~,
  )
  guard report is Object(fields) else { fail("invalid proof result") }
  if proof_field(run, "failed") != Json(0) {
    fields["reviewed_profile_passed"] = Json(false)
    fields["full_catalog_qualified"] = Json(false)
  }
  fields["revision"] = Json(revision)
  fields["freshness_checked"] = Json(true)
  fields["proof_definitions_sha256"] = Json(
    @testkit.sha256_bytes(@utf8.encode(manifest_text)),
  )
  fields["current_driver_build_checked"] = Json(true)
  fields["checked_at_ms"] = Json(@async.now())
  fields["executed_definitions_sha256"] = proof_field(
    run, "case_definitions_sha256",
  )
  fields["executed_scenario_proofs_sha256"] = proof_field(
    run, "scenario_proofs_sha256",
  )
  fields["scope"] = Json(
    "finite reviewed contracts joined to actual same-run asserted results; unresolved claims and excluded platforms remain unqualified",
  )
  @fs.write_file(output, report.stringify(indent=2) + "\n")
  let require_full = options.get("--require-full").unwrap_or("false")
  guard ["true", "false"].contains(require_full) else {
    fail("--require-full must be true or false")
  }
  if proof_field(report, "reviewed_profile_passed") != Json(true) ||
    (
      require_full == "true" &&
      proof_field(report, "full_catalog_qualified") != Json(true)
    ) {
    @sys.exit(1)
  }
}
