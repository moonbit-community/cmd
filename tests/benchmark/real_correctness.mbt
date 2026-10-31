///|
async fn real_coverage(options : Map[String, String]) -> Json {
  let manifest = @json.parse(
    @fs.read_file(
      options.get("--manifest").unwrap_or("tests/benchmark/real.json"),
    ).text(),
  )
  @json.parse(
    @fs.read_file(
      real_registry_path(real_text(real_field(manifest, "coverage_registry"))),
    ).text(),
  )
}

///|
async fn real_selected_commands(
  options : Map[String, String],
  rows : Array[FunctionalWorkload],
) -> Set[String] {
  let result : Set[String] = Set([])
  if options.contains("--commands") {
    for row in rows {
      result.add(row.command)
    }
    return result
  }
  let coverage = real_coverage(options)
  for row in real_array(real_field(coverage, "commands")) {
    result.add(real_text(real_field(row, "command")))
  }
  result
}

///|
fn real_local_result_errors(
  required : Array[@testkit.Case],
  results : Array[Json],
  run : Json,
  platform : String,
) -> Array[String] {
  let errors : Array[String] = []
  if required.is_empty() || results.length() != required.length() {
    errors.push("missing or extra local contract results")
  }
  for definition in required {
    let matches = results.filter(row => {
      real_field(row, "id") == Json(definition.id)
    })
    guard matches is [result] else {
      errors.push("missing or duplicate local identity: " + definition.id)
      continue
    }
    if real_field(result, "command") != Json(definition.command) ||
      real_field(result, "platform") != Json(platform) ||
      real_field(result, "backend") != Json("wasm") ||
      ![Json("contract"), Json("boundary")].contains(
        real_field(result, "verification"),
      ) ||
      real_field(result, "missing_observations") != Json::array([]) {
      errors.push(
        "local ownership/runtime/observations mismatch: " + definition.id,
      )
    }
    let applies = match definition.host_platforms {
      None => true
      Some(names) =>
        names.contains(platform) ||
        (names.contains("posix") && ["linux", "macos"].contains(platform))
    }
    if applies {
      if real_field(result, "result") != Json("pass") ||
        real_field(result, "stage") != Json("complete") {
        errors.push(
          "applicable local witness did not complete: " + definition.id,
        )
      }
      let observations = real_array(real_field(result, "observations"))
      for
        required in [
          "status",
          "stdout",
          "stderr",
          ..@testkit.contract_observations(definition),
        ] {
        if !observations.contains(Json(required)) {
          errors.push(
            "local required observation missing: " +
            definition.id +
            ":" +
            required,
          )
        }
      }
    } else if real_field(result, "result") != Json("skip") ||
      real_field(result, "stage") != Json("platform") {
      errors.push("illegal platform skip: " + definition.id)
    }
  }
  let passed = results
    .filter(row => real_field(row, "result") == Json("pass"))
    .length()
  let skipped = results
    .filter(row => real_field(row, "result") == Json("skip"))
    .length()
  if passed == 0 ||
    passed + skipped != results.length() ||
    real_field(run, "failed") != Json(0) ||
    real_field(run, "passed") != Json(passed) ||
    real_field(run, "skipped") != Json(skipped) {
    errors.push(
      "local counters, failure status or all-skip selection cannot qualify",
    )
  }
  errors
}

///|
async fn run_real_local_contracts(
  options : Map[String, String],
  rows : Array[FunctionalWorkload],
  output : String,
) -> Unit {
  let coverage = real_coverage(options)
  let commands = real_selected_commands(options, rows)
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(
      @fs.read_file(
        options.get("--manifest").unwrap_or("tests/benchmark/real.json"),
      ).text(),
    ),
  )
  let case_path = real_registry_path(functional_case_corpus(manifest, true))
  let definitions = @testkit.load_cases(case_path)
  let cases : Set[String] = Set([])
  for spec in real_array(real_field(coverage, "commands")) {
    if commands.contains(real_text(real_field(spec, "command"))) {
      for id in real_array(real_field(spec, "local_case_ids")) {
        guard definitions.filter(fixture => {
            fixture.id == real_text(id) ||
            fixture.aliases.unwrap_or([]).contains(real_text(id))
          })
          is [definition] else {
          fail("ambiguous local correctness identity: " + real_text(id))
        }
        cases.add(definition.id)
      }
    }
  }
  guard !cases.is_empty() &&
    options.get("--correctness-driver") is Some(driver) &&
    @path.Path(driver).is_absolute() &&
    options.get("--wasm-root") is Some(wasm) else {
    fail(
      "real performance requires an explicit freshly built correctness driver and frozen Wasm artifacts",
    )
  }
  let local_manifest = output + "/local-cases.json"
  let descriptors = @json.parse(
    @fs.read_file(real_registry_path("tests/fixtures/runner/cases.json")).text(),
  )
  write_json(local_manifest, {
    "schema": 2,
    "commands": real_field(descriptors, "commands"),
    "cases": Json(definitions),
  })
  let local_manifest_sha = benchmark_file_sha256(local_manifest)
  let args = [
    "--suite",
    "functional",
    "--jobs",
    "1",
    "--manifest",
    @fs.realpath(local_manifest),
    "--wasm-root",
    wasm,
    "--report-dir",
    output + "/local-contracts",
  ]
  let ids = cases.to_array()
  ids.sort()
  for id in ids {
    args.append(["--case", id])
  }
  let capture = @process.redirect_to_file(output + "/local-contracts.log")
  defer capture.close()
  let status = @async.with_timeout_opt(180000, () => {
    @process.run(
      driver,
      args,
      stdout=capture,
      stderr=capture,
      cancel_handler=@process.hard_cancel(),
    )
  })
  guard status == Some(0) else {
    fail(
      "independent local correctness witnesses failed before timing; see local-contracts.log",
    )
  }
  assert_eq(
    benchmark_file_sha256(local_manifest),
    local_manifest_sha,
    msg="local case manifest changed during execution",
  )
  let run = @json.parse(
    @fs.read_file(output + "/local-contracts/run.json").text(),
  )
  guard real_field(run, "failed") == Json(0) else {
    fail("local correctness run contains failure")
  }
  let actual = @fs.read_file(output + "/local-contracts/summary.jsonl").text()
  guard real_field(run, "results_sha256") ==
    Json(@testkit.sha256_bytes(@utf8.encode(actual))) else {
    fail("local correctness result hash differs")
  }
  let results : Array[Json] = []
  for line in actual.split("\n") {
    if !line.is_empty() {
      results.push(@json.parse(line.to_owned()))
    }
  }
  guard results.length() == ids.length() &&
    results.all(row => {
      [Json("pass"), Json("skip")].contains(real_field(row, "result"))
    }) else {
    fail("missing, duplicate or unsuccessful local correctness results")
  }
  let errors = real_local_result_errors(
    definitions.filter(definition => cases.contains(definition.id)),
    results,
    run,
    @testkit.host_platform(),
  )
  guard errors.is_empty() else { fail(errors.join("\n")) }
  write_json(output + "/local-correctness.json", {
    "passed": true,
    "required_case_ids": Json(ids),
    "commands": Json(commands.to_array()),
    "skipped": real_field(run, "skipped"),
    "driver_sha256": benchmark_file_sha256(driver),
    "results_sha256": real_field(run, "results_sha256"),
    "scope": "independent local contracts through the explicit frozen driver before real-input timing; fresh-source identity is established by the build wrappers; explicit platform exclusions retained; no oracle substituted",
  })
}
