///|
priv struct FunctionalRow {
  workload : FunctionalWorkload
  role : String
  status : String
  detail : String
  trials : Array[TrialRecord]
  samples : Array[PairedSample]
  result : RowResult?
  probe : Json?
} derive(ToJson)

///|
priv struct FunctionalSide {
  observation : ProcessObservation
  root : String
  stdout : String
  stderr : String
  errors : Array[String]
}

///|
fn functional_candidate(
  command : String,
  args : Array[String],
  options : Map[String, String],
) -> (String, Array[String]) raise {
  guard options.get("--wasm-root") is Some(root) else {
    fail("real-source comparisons require explicit Wasm artifacts")
  }
  (options["--moonrun"], [@testkit.wasm_path(root, command), "--", ..args])
}

///|

///|
async fn execute_functional_side(
  side : String,
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  options : Map[String, String],
  oracle_bin : String,
  environment : Map[String, String],
  directory : String,
  http_base : String,
  timeout_ms : Int32,
  corpus : PreparedCorpus?,
) -> FunctionalSide {
  let root = directory + "/" + side + ".work"
  reset_functional_fixture(root, fixture, http_base)
  prepare_real_inputs(workload, root, corpus)
  prepare_benchmark_recipe(
    workload,
    corpus,
    root,
    oracle=oracle_bin,
    environment~,
    timeout_ms~,
  )
  guard corpus is Some(prepared) else {
    fail("real-source invocation has no frozen genuine input")
  }
  let input = prepared.input
  let actual_args = fixture.args.map(arg => {
    arg.replace_all(old="${INPUT}", new=input)
  })
  let args = @testkit.expand_args(actual_args, root, http_base~)
  let extra = environment.copy()
  for
    name, value in @testkit.expand_environment(
      fixture.environment,
      root,
      http_base~,
    ) {
    extra[name] = value
  }
  let candidate = side == "candidate"
  apply_benchmark_reference_profile(
    extra,
    workload.command,
    !candidate && !options.contains("--baseline-wasm-root"),
  )
  let (program, argv) = if candidate {
    functional_candidate(fixture.command, args, options)
  } else {
    match options.get("--baseline-wasm-root") {
      Some(baseline) =>
        (
          options["--moonrun"],
          [@testkit.wasm_path(baseline, fixture.command), "--", ..args],
        )
      None => (oracle_bin + "/" + fixture.command, args)
    }
  }
  let invocation : BenchmarkInvocation = {
    program,
    args: argv,
    cwd: fixture.working_directory(root),
    environment: extra,
    stdin_path: input,
  }
  write_json(
    directory + "/" + side + ".invocation.json",
    ToJson::to_json(invocation),
  )
  let stdout = directory + "/" + side + ".stdout.bin"
  let stderr = directory + "/" + side + ".stderr.bin"
  let named_inputs : Array[(String, String)] = []
  if benchmark_file_recipe(workload.recipe) {
    for name in ["left", "right"] {
      let path = root + "/" + name
      let digest = benchmark_file_sha256(path)
      named_inputs.push((path, digest))
      let receipt = directory +
        "/" +
        side +
        "." +
        name +
        ".observed-features.json"
      let features = if @fs.exists(receipt) {
        @json.parse(@fs.read_file(receipt).text())
      } else {
        let features = observe_benchmark_features(path)
        write_json(receipt, features)
        features
      }
      guard features is { "sha256": String(expected), .. } && expected == digest else {
        fail(
          "recreated named input differs from its observed identity: " + path,
        )
      }
    }
  }
  let observation = if workload.sink == Some("slow-pipe") {
    measure_invocation_slow_output(
      invocation,
      stdout,
      stderr,
      timeout_ms,
      workload.sink_chunk_bytes.unwrap(),
      workload.sink_delay_ms.unwrap(),
    )
  } else if workload.transport == Some("fragmented-pipe") {
    measure_invocation_pipe(
      invocation,
      stdout,
      stderr,
      timeout_ms,
      workload.chunk_bytes.unwrap(),
      allow_early_close=workload.facets.unwrap_or([]).contains("early-exit"),
    )
  } else {
    measure_invocation(invocation, stdout, stderr, timeout_ms)
  }
  let errors : Array[String] = []
  if workload.command == "rev" && corpus is Some(prepared) {
    let expected = directory + "/independent-rev.stdout.bin"
    if ascii_reversal_expected(prepared.source, expected) {
      let valid = files_equal(stdout, expected)
      write_json(directory + "/" + side + ".reversal-calibration.json", {
        "relation": "per-record ASCII reversal preserving LF and final unterminated record",
        "passed": valid,
        "source_sha256": benchmark_file_sha256(prepared.source),
        "expected_sha256": benchmark_file_sha256(expected),
        "actual_sha256": benchmark_file_sha256(stdout),
        "role": if candidate {
          "candidate semantic relation"
        } else {
          "reference calibration"
        },
      })
      if !valid {
        errors.push(
          if candidate {
            "candidate violates independent ASCII reversal relation"
          } else {
            "invalid-native-reference: independent ASCII reversal relation failed; no ratio can qualify"
          },
        )
      }
    }
  }
  for (path, digest) in named_inputs {
    if benchmark_file_sha256(path) != digest {
      errors.push("named input changed during invocation: " + path)
    }
  }
  if observation.error is Some(error) {
    errors.push(error)
  }
  if observation.timed_out {
    errors.push("deadline expired; captured output is partial")
  }
  if !finite_positive(observation.elapsed_us) {
    errors.push("duration must be finite and positive")
  }
  if observation.status is Some(status) &&
    !observation.timed_out &&
    observation.error is None {
    {
      errors.append(
        @testkit.check_contract(
          fixture,
          {
            status,
            stdout: if corpus is Some(_) {
              b""
            } else {
              bounded_capture(stdout)
            },
            stderr: bounded_capture(stderr),
          },
          root,
        ),
      )
      errors.append(@testkit.check_expected_files(fixture, root))
    }
    if workload.recipe == Some("gzip") {
      let decoded = directory + "/" + side + ".decoded.bin"
      let equal = try {
        corpus_observer(
          oracle_bin + "/gzip",
          ["-d", "-c"],
          stdout,
          decoded,
          environment,
          timeout_ms,
        )
        files_equal(decoded, prepared.source)
      } catch {
        failure => {
          errors.push("gzip observer: " + failure.to_string())
          false
        }
      }
      if !equal {
        errors.push("gzip output does not decode to the original input")
      }
    } else if corpus is Some(prepared) &&
      (workload.command == "gunzip" || workload.command == "zcat") &&
      !files_equal(stdout, prepared.source) {
      errors.push("decoded output differs from the genuine source")
    }
    if workload.expected_stdout is Some(expected) &&
      bounded_capture(stdout) != @utf8.encode(expected) {
      errors.push("stdout differs from independent workload assertion")
    }
    if workload.facets.unwrap_or([]).contains("network") &&
      corpus is Some(prepared) {
      errors.append(real_http_output_errors(prepared.source, stdout))
    }
    if corpus is Some(prepared) &&
      workload.recipe is Some(recipe) &&
      ["bench-split-byte-chunks", "bench-csplit-boundaries"].contains(recipe) {
      errors.append(
        check_partition_source(
          root,
          prepared.source,
          if recipe == "bench-csplit-boundaries" {
            if fixture.args.contains("/^SQLITE_API /") {
              Some(b"SQLITE_API ")
            } else {
              Some(b"SECTION ")
            }
          } else {
            None
          },
        ),
      )
    }
  } else if errors.is_empty() {
    errors.push("process has no completed status")
  }
  { observation, root, stdout, stderr, errors, }
}

///|
async fn compare_functional_sides(
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  candidate : FunctionalSide,
  upstream : FunctionalSide,
) -> Array[String] {
  let errors : Array[String] = []
  if candidate.observation.status != upstream.observation.status {
    errors.push("candidate/upstream exit statuses differ")
  }
  if workload.recipe != Some("gzip") {
    let same = match workload.output_relation {
      Some("json") =>
        @json.parse(@utf8.decode(bounded_capture(candidate.stdout))) ==
        @json.parse(@utf8.decode(bounded_capture(upstream.stdout)))
      Some("record-multiset") =>
        @testkit.unordered_lines_equal(
          bounded_capture(candidate.stdout),
          bounded_capture(upstream.stdout),
        )
      _ => files_equal(candidate.stdout, upstream.stdout)
    }
    if !same {
      errors.push("stdout declared relation differs")
    }
  }
  if !files_equal(candidate.stderr, upstream.stderr) {
    errors.push("stderr bytes differ")
  }
  errors.append(
    compare_functional_effects(
      candidate.root,
      upstream.root,
      @testkit.contract_observations(fixture),
    ),
  )
  errors
}

///|

///|
async fn functional_pair(
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  options : Map[String, String],
  environment : Map[String, String],
  directory : String,
  http_base : String,
  timeout_ms : Int32,
  phase : String,
  pair : Int32,
  block : Int32?,
  order : PairOrder,
  trials : Array[TrialRecord],
  corpus : PreparedCorpus?,
) -> (PairedSample?, String) {
  let observed : Map[String, FunctionalSide] = Map([])
  for
    side in (match order {
      CandidateFirst => ["candidate", "upstream"]
      UpstreamFirst => ["upstream", "candidate"]
    }) {
    let completed = execute_functional_side(
      side,
      workload,
      fixture,
      options,
      options["--oracle-bin"],
      environment,
      directory,
      http_base,
      timeout_ms,
      corpus,
    )
    let trial : TrialRecord = {
      phase,
      pair,
      block,
      side,
      observation: completed.observation,
      correct: completed.errors.is_empty(),
      detail: completed.errors.join("; "),
      stdout_path: completed.stdout,
      stderr_path: completed.stderr,
      stdout_bytes: Some(@fs.file_size(completed.stdout)),
    }
    trials.push(trial)
    append_jsonl(directory + "/trials.jsonl", ToJson::to_json(trial))
    if !completed.errors.is_empty() {
      return (None, side + ": " + completed.errors.join("; "))
    }
    observed[side] = completed
  }
  let candidate = observed["candidate"]
  let upstream = observed["upstream"]
  let errors = compare_functional_sides(workload, fixture, candidate, upstream)
  write_json(directory + "/comparison.json", {
    "phase": Json(phase),
    "pair": Json(pair),
    "errors": Json(errors),
    "candidate_output_bytes": Json(@fs.file_size(candidate.stdout).to_string()),
    "upstream_output_bytes": Json(@fs.file_size(upstream.stdout).to_string()),
  })
  if !errors.is_empty() {
    return (None, errors.join("; "))
  }
  (
    Some({
      candidate_us: candidate.observation.elapsed_us,
      upstream_us: upstream.observation.elapsed_us,
    }),
    "",
  )
}

///|
async fn run_functional_row(
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  options : Map[String, String],
  environment : Map[String, String],
  output : String,
  http_base : String,
  timeout_ms : Int32,
  sample : Bool,
  completed_corpora : Map[String, Bool],
  real_http_payload : Ref[String?],
) -> FunctionalRow {
  let directory = output + "/" + workload.id
  @fs.mkdir(directory)
  write_json(directory + "/fixture.json", ToJson::to_json(fixture))
  write_json(directory + "/workload-evidence.json", {
    "scope": benchmark_evidence_scope(sample),
    "output_sink": functional_output_sink(workload),
    "reference_profile": benchmark_reference_profile(
      workload.command,
      wasm_baseline=options.contains("--baseline-wasm-root"),
    ),
    "environment_mode": "recorded explicit overrides plus inherited host environment; not a hermetic container profile",
    "input_transport": if benchmark_file_recipe(workload.recipe) {
      "distinct-named-files"
    } else {
      workload.transport.unwrap_or("redirected-regular-file")
    },
    "producer_chunk_bytes": ToJson::to_json(workload.chunk_bytes),
    "consumer_chunk_bytes": ToJson::to_json(workload.sink_chunk_bytes),
    "consumer_delay_ms": ToJson::to_json(workload.sink_delay_ms),
    "source_role": if benchmark_file_recipe(workload.recipe) {
      "complete genuine named sources; declared copies or sorted/key-derived preparation outside timing"
    } else {
      "complete genuine source or declared semantic codec encoding"
    },
    "source": ToJson::to_json(workload.source),
    "blind_holdout": false,
    "metadata_shortcut_possible": functional_metadata_shortcut(
      workload,
      fixture.args,
    ),
  })
  let corpus = prepare_natural_source(
    workload,
    directory,
    options,
    options["--oracle-bin"],
    environment,
    timeout_ms,
    completed_corpora,
  )
  let input_identities : Array[(String, String)] = []
  if corpus is Some(prepared) {
    input_identities.push(
      (prepared.source, benchmark_file_sha256(prepared.source)),
    )
    if workload.other_source is Some(other) {
      let path = @path.Path(prepared.source)
        .dirname()
        .join(Path("natural-" + other.sha256 + ".bin"))
        .to_string()
      input_identities.push((path, benchmark_file_sha256(path)))
    }
    for item in workload.inputs.unwrap_or([]) {
      let path = @path.Path(prepared.source)
        .dirname()
        .join(Path("natural-" + item.source.sha256 + ".bin"))
        .to_string()
      if !input_identities.any(pair => pair.0 == path) {
        input_identities.push((path, benchmark_file_sha256(path)))
      }
    }
    if prepared.input != prepared.source {
      input_identities.push(
        (prepared.input, benchmark_file_sha256(prepared.input)),
      )
    }
    write_json(directory + "/input-identities.json", Json(input_identities))
    let observations : Array[Json] = []
    for (path, expected) in input_identities {
      let observed = ensure_benchmark_features(path)
      guard observed is { "sha256": String(actual), .. } && actual == expected else {
        fail(
          "input feature cache differs from the frozen file identity: " + path,
        )
      }
      guard observed is Object(fields) else {
        fail("input feature object required")
      }
      let enriched = fields.copy()
      if workload.facets.unwrap_or([]).contains("utf8") {
        let valid = try {
          ignore(@utf8.decode(@fs.read_file(path).binary()))
          true
        } catch {
          _ => false
        }
        enriched["valid_utf8"] = Json(valid)
      }
      observations.push(Json(enriched))
    }
    write_json(directory + "/input-observations.json", Json(observations))
    let feature_errors = real_observation_errors(workload, observations)
    guard feature_errors.is_empty() else { fail(feature_errors.join("\n")) }
    real_http_payload.val = Some(prepared.source)
  }
  let trials : Array[TrialRecord] = []
  let samples : Array[PairedSample] = []
  let mut detail = ""
  let mut correct = true
  let run = async fn(phase, pair, block, order) {
    let (observed, reason) = functional_pair(
      workload, fixture, options, environment, directory, http_base, timeout_ms,
      phase, pair, block, order, trials, corpus,
    )
    detail = reason
    observed
  }
  // Compare actual work before admitting any timed sample.
  if run("correctness", 0, None, CandidateFirst) is None {
    correct = false
  }
  if correct && options.contains("--baseline-wasm-root") {
    let native = options.copy()
    ignore(native.remove("--baseline-wasm-root"))
    let (observed, reason) = functional_pair(
      workload,
      fixture,
      native,
      environment,
      directory,
      http_base,
      timeout_ms,
      "native-correctness",
      0,
      None,
      CandidateFirst,
      trials,
      corpus,
    )
    if observed is None {
      correct = false
      detail = reason
    }
  }
  let count = probe_pairs(options)
  if sample && correct && count > 0 {
    let window = @string.parse_int(options.get("--window").unwrap_or("0"))
    guard window == 0 || window == 1 else {
      fail("probe window must be 0 or 1")
    }
    if run("warmup", 0, None, pair_order(window)) is None {
      correct = false
    }
    if correct {
      for index in 0..<count {
        match run("measured", index, None, pair_order(index + window + 1)) {
          Some(value) => samples.push(value)
          None => {
            correct = false
            break
          }
        }
      }
    }
  } else if sample && correct {
    let plan = sampling_plan()
    for index, order in plan.warmups {
      if run("warmup", index, None, order) is None {
        correct = false
        break
      }
    }
    if correct {
      for pair in plan.pairs {
        match run("measured", pair.index, Some(pair.block), pair.order) {
          Some(value) => samples.push(value)
          None => {
            correct = false
            break
          }
        }
      }
    }
  }
  for (path, expected) in input_identities {
    if benchmark_file_sha256(path) != expected {
      correct = false
      detail = "input changed during measurement: " + path
    }
  }
  let result = if sample && count == 0 {
    Some(summarize_row(samples, correctness_ok=correct))
  } else {
    None
  }
  let row = {
    workload,
    role: "direct-wasm",
    status: if detail.contains("invalid-native-reference:") {
      "invalid-reference"
    } else if correct {
      "checked"
    } else {
      "failed"
    },
    detail,
    trials,
    samples,
    result,
    probe: if count > 0 {
      Some(probe_summary(samples, count, correct))
    } else {
      None
    },
  }
  write_json(directory + "/row.json", ToJson::to_json(row))
  row
}

///|
fn failed_functional_row(
  workload : FunctionalWorkload,
  detail : String,
) -> FunctionalRow {
  {
    workload,
    role: "direct-wasm",
    status: "failed",
    detail,
    trials: [],
    samples: [],
    result: None,
    probe: None,
  }
}

///|
async fn run_functional(options : Map[String, String], sample~ : Bool) -> Bool {
  require_frozen_timing_backend(options)
  let manifest_path = options
    .get("--manifest")
    .unwrap_or("tests/benchmark/real.json")
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file(manifest_path).text()),
  )
  guard manifest.schema == 3 else {
    fail(
      "functional comparisons require schema3 complete real-source workloads",
    )
  }
  let ordered = functional_inventory(options)
  validate_real_source_sizes(options, ordered)
  let workloads = if options.get("--window") == Some("1") {
    Array::makei(ordered.length(), i => ordered[ordered.length() - 1 - i])
  } else {
    ordered
  }
  let timeout_ms = 120000
  let configuration : Json = {
    "timeout_ms": timeout_ms,
    "locale": "C",
    "timezone": "UTC",
    "qualification": "Actual frozen reference executable identities; not sealed-container parity",
  }
  let launcher = options.get("--moonrun").unwrap_or("")
  let oracle = options.get("--oracle-bin").unwrap_or("")
  guard @path.Path(launcher).is_absolute() && @path.Path(oracle).is_absolute() else {
    fail("explicit absolute --moonrun and --oracle-bin are required")
  }
  if options.get("--wasm-root") is Some(root) && !@path.Path(root).is_absolute() {
    fail("--wasm-root requires an absolute release artifact directory")
  }
  if options.get("--baseline-wasm-root") is Some(root) {
    guard @path.Path(root).is_absolute() else {
      fail("baseline Wasm comparison requires two absolute artifact roots")
    }
  }
  let case_corpus = manifest.case_corpus
  let output = @path.Path(
      options
      .get("--report-dir")
      .unwrap_or(
        "test-reports/performance/functional-" + @async.now().to_string(),
      ),
    )
    .resolve()
    .to_string()
  guard !@fs.exists(output) else { fail("choose a fresh report directory") }
  @fs.mkdir(output, recursive=true)
  @fs.mkdir(output + "/corpora")
  let (options, artifact_identities) = freeze_functional_artifacts(
    options, workloads, output,
  )
  let oracle = options["--oracle-bin"]
  {
    run_real_local_contracts(options, workloads, output)
    artifact_identities.push(
      (
        output + "/local-cases.json",
        benchmark_file_sha256(output + "/local-cases.json"),
      ),
    )
  }
  let launcher = options["--moonrun"]
  let environment = @testkit.controlled_environment(Map([]))
  guard @env.get_env_var("MOON_HOME") is Some(account) && account != "" else {
    fail("MOON_HOME is required")
  }
  environment["MOON_HOME"] = account
  environment["PATH"] = oracle + ":" + @env.get_env_var("PATH").unwrap_or("")
  let probes = [
    observe_profile("moon", ["version", "--all"]),
    observe_profile(launcher, ["--version"]),
    observe_profile("uname", ["-a"]),
    observe_profile("git", ["rev-parse", "HEAD"]),
    observe_profile("git", ["status", "--short"]),
    observe_profile("df", ["-Pk", output]),
  ]
  write_json(output + "/profile.json", {
    "configuration": configuration,
    "native_reference": {
      "binding": "actual-frozen-executable-identities",
      "oracle_bin": oracle,
    },
    "environment": ToJson::to_json(environment),
    "platform": Json(@testkit.host_platform()),
    "candidate_role": Json("direct-wasm"),
    "wasm_root": ToJson::to_json(options.get("--wasm-root")),
    "observations": ToJson::to_json(probes),
    "case_corpus": case_corpus,
    "evidence_scope": benchmark_evidence_scope(sample),
    "input_policy": "Schema3 timing uses complete hash-pinned real sources, without repetition, padding or trimming. Generated timing inputs and legacy execution routes are absent.",
  })
  write_json(output + "/manifest.json", ToJson::to_json(manifest))
  write_json(output + "/selected-workloads.json", ToJson::to_json(workloads))
  if sample && probe_pairs(options) == 0 {
    write_json(output + "/sampling-plan.json", ToJson::to_json(sampling_plan()))
  }
  let rows : Array[FunctionalRow] = []
  let completed_corpora : Map[String, Bool] = Map([])
  @async.with_task_group(group => {
    let real_http_payload : Ref[String?] = Ref(None)
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    let serving = group.spawn(() => {
      run_real_http_fixture(server, real_http_payload)
    })
    defer serving.cancel()
    let http_base = "http://127.0.0.1:" + server.addr.port().to_string()
    for workload in workloads {
      let fixture = functional_fixture(workload)
      let fixture = {
        ..fixture,
        args: workload.args.unwrap_or(fixture.args),
        expected_status: workload.expected_status.unwrap_or(
          fixture.expected_status,
        ),
      }
      println("functional " + workload.id)
      let row = run_functional_row(
        workload, fixture, options, environment, output, http_base, timeout_ms, sample,
        completed_corpora, real_http_payload,
      ) catch {
        error =>
          {
            ..failed_functional_row(workload, error.to_string()),
            status: "failed",
          }
      }
      rows.push(row)
    }
    serving.cancel()
    serving.wait() catch {
      @async.WaitedTaskAlreadyCancelled => ()
      error => raise error
    }
  })
  let mut artifact_integrity = true
  for (path, expected) in artifact_identities {
    if benchmark_file_sha256(path) != expected {
      artifact_integrity = false
    }
  }
  let checked = artifact_integrity &&
    !rows.is_empty() &&
    rows.all(row => row.status == "checked")
  let passed = checked &&
    (
      !sample ||
      rows.all(row => {
        if probe_pairs(options) > 0 {
          row.probe is Some({ "passed": True, .. })
        } else {
          row.result is Some(result) && result.verdict is Pass
        }
      })
    )
  write_json(output + "/report.json", {
    "schema": 3,
    "sampled": Json(sample),
    "evidence_scope": benchmark_evidence_scope(sample),
    "passed": Json(passed),
    "scope": "selected command-mode/corpus rows only; diagnostic probe and formal statistics remain separate",
    "probe_pairs": probe_pairs(options),
    "artifact_integrity": artifact_integrity,
    "rows": ToJson::to_json(rows),
  })
  println("functional baseline report: " + output + "/report.json")
  passed
}
