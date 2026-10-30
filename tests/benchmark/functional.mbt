///|
priv struct FunctionalRow {
  workload : FunctionalWorkload
  coordinate : String?
  role : String
  status : String
  detail : String
  trials : Array[TrialRecord]
  samples : Array[PairedSample]
  result : RowResult?
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
  coordinate : String?,
  options : Map[String, String],
) -> (String, Array[String]) raise {
  if options.get("--wasm-root") is Some(root) {
    (options["--moonrun"], [@testkit.wasm_path(root, command), "--", ..args])
  } else if coordinate is Some(coordinate) {
    (options["--moonx"], [coordinate, "--", ..args])
  } else {
    fail(
      "functional candidate requires Wasm artifacts or an exact published coordinate",
    )
  }
}

///|
async fn execute_functional_side(
  side : String,
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  coordinate : String?,
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
  let input = match corpus {
    Some(prepared) => prepared.input
    None => {
      let path = directory + "/" + side + ".stdin.bin"
      @fs.write_file(path, fixture.input(root~, http_base~))
      path
    }
  }
  let args = @testkit.expand_args(fixture.args, root, http_base~)
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
  let (program, argv) = if candidate {
    functional_candidate(fixture.command, args, coordinate, options)
  } else {
    (oracle_bin + "/" + fixture.command, args)
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
  let observation = if workload.recipe == Some("yes") {
    observe_yes(invocation, stdout, stderr, timeout_ms)
  } else {
    measure_invocation(invocation, stdout, stderr, timeout_ms)
  }
  let errors : Array[String] = []
  if observation.error is Some(error) {
    errors.push(error)
  }
  if observation.timed_out {
    errors.push("deadline expired; captured output is partial")
  }
  if observation.status is Some(status) &&
    !observation.timed_out &&
    observation.error is None {
    if workload.recipe != Some("yes") {
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
      let equal = match corpus {
        Some(prepared) =>
          try {
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
        None => gzip_roundtrip(stdout, input, decoded)
      }
      if !equal {
        errors.push("gzip output does not decode to the original input")
      }
    } else if corpus is Some(prepared) &&
      (workload.command == "gunzip" || workload.command == "zcat") &&
      !files_equal(stdout, prepared.source) {
      errors.push("decoded output differs from the generated corpus")
    }
    errors.append(check_generated_effects(workload.recipe, root, stdout))
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
  if workload.recipe != Some("mktemp") {
    for
      (field, left, right) in [
        ("stdout", candidate.stdout, upstream.stdout),
        ("stderr", candidate.stderr, upstream.stderr),
      ] {
      if field == "stdout" && workload.recipe == Some("gzip") {
        continue
      }
      let rules = fixture.normalizations.copy()
      let literal = if field == "stdout" {
        fixture.expected_stdout_text
      } else {
        fixture.expected_stderr_text
      }
      if literal.unwrap_or("").contains("${WORK}") {
        rules.push({
          field,
          rule: "temporary-path",
          comment: "The fixture explicitly expects its own root.",
        })
      }
      if rules.is_empty() && fixture.stdout_order != Some("lines") {
        if !files_equal(left, right) {
          errors.push(field + " bytes differ")
        }
      } else {
        let left = @testkit.normalize_text(
          bounded_capture(left),
          field,
          rules,
          candidate.root,
        )
        let right = @testkit.normalize_text(
          bounded_capture(right),
          field,
          rules,
          upstream.root,
        )
        let same = if field == "stdout" && fixture.stdout_order == Some("lines") {
          @testkit.unordered_lines_equal(left, right)
        } else {
          left == right
        }
        if !same {
          errors.push(field + " normalized bytes differ")
        }
      }
    }
    errors.append(
      compare_functional_effects(
        candidate.root,
        upstream.root,
        @testkit.contract_observations(fixture),
      ),
    )
  }
  errors
}

///|
async fn functional_pair(
  workload : FunctionalWorkload,
  fixture : @testkit.Case,
  coordinate : String?,
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
      coordinate,
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
  coordinate : String?,
  options : Map[String, String],
  environment : Map[String, String],
  output : String,
  http_base : String,
  timeout_ms : Int32,
  sample : Bool,
  completed_corpora : Map[String, Bool],
) -> FunctionalRow {
  let directory = output + "/" + workload.id
  @fs.mkdir(directory)
  write_json(directory + "/fixture.json", ToJson::to_json(fixture))
  let corpus = prepare_row_corpus(
    workload,
    directory,
    options["--oracle-bin"],
    environment,
    timeout_ms,
    completed_corpora,
  )
  let trials : Array[TrialRecord] = []
  let samples : Array[PairedSample] = []
  let mut detail = ""
  let mut correct = true
  let run = async fn(phase, pair, block, order) {
    let (observed, reason) = functional_pair(
      workload, fixture, coordinate, options, environment, directory, http_base,
      timeout_ms, phase, pair, block, order, trials, corpus,
    )
    detail = reason
    observed
  }
  // Compare actual work before admitting any timed sample.
  if run("correctness", 0, None, CandidateFirst) is None {
    correct = false
  }
  if sample && correct {
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
  let result = if sample {
    Some(summarize_row(samples, correctness_ok=correct))
  } else {
    None
  }
  let row = {
    workload,
    coordinate,
    role: if options.contains("--wasm-root") {
      "direct-wasm"
    } else if coordinate is Some(_) {
      "delivery"
    } else {
      "diagnostic-only"
    },
    status: if correct {
      "checked"
    } else {
      "failed"
    },
    detail,
    trials,
    samples,
    result,
  }
  write_json(directory + "/row.json", ToJson::to_json(row))
  row
}

///|
fn pending_functional_row(
  workload : FunctionalWorkload,
  coordinate : String?,
  detail : String,
) -> FunctionalRow {
  {
    workload,
    coordinate,
    role: "pending",
    status: "pending",
    detail,
    trials: [],
    samples: [],
    result: None,
  }
}

///|
async fn run_functional(options : Map[String, String], sample~ : Bool) -> Bool {
  let manifest_path = options
    .get("--manifest")
    .unwrap_or("tests/benchmark/functional.json")
  let manifest : FunctionalManifest = @json.from_json(
    @json.parse(@fs.read_file(manifest_path).text()),
  )
  guard manifest.schema == 2 else {
    fail("functional manifest requires schema2")
  }
  let base : FunctionalManifest? = match manifest.base_manifest {
    Some(path) => Some(@json.from_json(@json.parse(@fs.read_file(path).text())))
    None => None
  }
  let workloads = expand_corpus_sweeps(
    manifest,
    base.map(item => item.workloads).unwrap_or([]),
  )
  let profile_path = options
    .get("--profile")
    .unwrap_or("tests/benchmark/profile-full.json")
  let configuration = @json.parse(@fs.read_file(profile_path).text())
  let profile : PilotProfile = @json.from_json(configuration)
  guard profile.role == "delivery" &&
    profile.cache == "warm" &&
    profile.locale == "C" &&
    profile.timezone == "UTC" else {
    fail("expected warm delivery profile with C locale and UTC")
  }
  let wasm = options.contains("--wasm-root")
  let launcher = options
    .get(if wasm { "--moonrun" } else { "--moonx" })
    .unwrap_or("")
  let oracle = options.get("--oracle-bin").unwrap_or("")
  guard @path.Path(launcher).is_absolute() && @path.Path(oracle).is_absolute() else {
    fail(
      "explicit absolute launcher (--moonrun or --moonx) and --oracle-bin are required",
    )
  }
  if options.get("--wasm-root") is Some(root) && !@path.Path(root).is_absolute() {
    fail("--wasm-root requires an absolute release artifact directory")
  }
  let record = @json.parse(@fs.read_file(profile.oracle_build_record).text())
  let built : OracleBuildRoot = @json.from_json(record)
  guard @fs.realpath(oracle) == @fs.realpath(built.prefix + "/bin") else {
    fail("oracle directory differs from its build record")
  }
  let published : PublishedManifest = @json.from_json(
    @json.parse(@fs.read_file(manifest.published_manifest).text()),
  )
  let registry = @registry.load("tests/registry/registry.json")
  let cases = @testkit.load_cases(manifest.case_corpus)
  let helper = @fs.realpath(@env.args()[0])
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
  let environment = @testkit.controlled_environment(Map([]))
  guard @env.get_env_var("MOON_HOME") is Some(account) && account != "" else {
    fail("MOON_HOME is required")
  }
  environment["MOON_HOME"] = account
  environment["PATH"] = oracle + ":" + @env.get_env_var("PATH").unwrap_or("")
  let records : Array[Json] = [record]
  if configuration is { "additional_oracle_build_records": paths, .. } {
    let paths : Array[String] = @json.from_json(paths)
    for path in paths {
      records.push(@json.parse(@fs.read_file(path).text()))
    }
  }
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
    "native_build_records": Json(records),
    "environment": ToJson::to_json(environment),
    "platform": Json(@testkit.host_platform()),
    "candidate_role": Json(if wasm { "direct-wasm" } else { "published-moonx" }),
    "wasm_root": ToJson::to_json(options.get("--wasm-root")),
    "observations": ToJson::to_json(probes),
    "corpus_generator": {
      "chunk_bytes": 65536,
      "entropy_seed": "0123456789abcdef0123456789abcdef",
      "entropy_format": "raw bytes; other shapes use the declared record size",
    },
  })
  write_json(output + "/manifest.json", ToJson::to_json(manifest))
  write_json(output + "/expanded-workloads.json", ToJson::to_json(workloads))
  if sample {
    write_json(output + "/sampling-plan.json", ToJson::to_json(sampling_plan()))
  }
  let rows : Array[FunctionalRow] = []
  let completed_corpora : Map[String, Bool] = Map([])
  @async.with_task_group(group => {
    let (server, reader, http_base) = @testkit.spawn_http_fixture_process(group)
    defer reader.close()
    defer server.cancel()
    for workload in workloads {
      guard @testkit.safe_relative_path(workload.id) &&
        registry.entries.any(entry => {
          (
            entry.behavior_id == workload.reference_behavior_id ||
            entry.aliases.contains(workload.reference_behavior_id)
          ) &&
          (entry.command == workload.command || entry.command == "all")
        }) else {
        fail("workload has no matching behavior reference: " + workload.id)
      }
      let matches = published.commands.filter(row => {
        row.name == workload.command && row.published
      })
      let coordinate = if wasm || workload.command == "timeout" {
        None
      } else {
        guard matches is [entry] else {
          fail("exact publication is missing: " + workload.command)
        }
        Some(entry.package_name + "@" + entry.version)
      }
      let pending = if workload.pending is Some(reason) {
        Some(reason)
      } else if !wasm && coordinate is None {
        Some("timeout is local-only; use workspace Wasm for its diagnostic")
      } else {
        None
      }
      if pending is Some(reason) {
        rows.push(pending_functional_row(workload, coordinate, reason))
        continue
      }
      let original = functional_fixture(workload, cases, helper)
      let fixture = match workload.corpus {
        Some(spec) => corpus_fixture(original, spec)
        None => original
      }
      if !fixture.platform_applies() {
        rows.push(
          pending_functional_row(
            workload, coordinate, "fixture is not applicable on this host",
          ),
        )
        continue
      }
      println("functional " + workload.id)
      let row = run_functional_row(
        workload,
        fixture,
        coordinate,
        options,
        environment,
        output,
        http_base,
        profile.timeout_ms,
        sample,
        completed_corpora,
      ) catch {
        error =>
          {
            ..pending_functional_row(workload, coordinate, error.to_string()),
            status: "failed",
          }
      }
      rows.push(row)
    }
    server.cancel()
    ignore(server.wait())
  })
  let checked = !rows.is_empty() && rows.all(row => row.status == "checked")
  let passed = checked &&
    (
      !sample ||
      rows.all(row => row.result is Some(result) && result.verdict is Pass)
    )
  write_json(output + "/report.json", {
    "schema": 2,
    "sampled": Json(sample),
    "passed": Json(passed),
    "complete_b2": false,
    "scope": "functional/startup baseline only; scale,resources and all host qualifications remain pending",
    "rows": ToJson::to_json(rows),
  })
  println("functional baseline report: " + output + "/report.json")
  passed
}
