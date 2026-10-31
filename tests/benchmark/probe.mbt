///|
fn probe_pairs(options : Map[String, String]) -> Int32 raise {
  match options.get("--probe-pairs") {
    None => 0
    Some(value) => {
      let count = @string.parse_int(value)
      guard count >= 3 && count <= 105 && count % 2 == 1 else {
        fail("probe pairs must be odd and in 3..105")
      }
      count
    }
  }
}

///|
fn probe_summary(
  samples : Array[PairedSample],
  expected : Int32,
  correct : Bool,
) -> Json {
  let complete = correct &&
    samples.length() == expected &&
    expected >= 3 &&
    samples.all(pair => {
      finite_positive(pair.candidate_us) && finite_positive(pair.upstream_us)
    })
  if !complete {
    return {
      "complete": false,
      "stable": false,
      "passed": false,
      "pairs": samples.length(),
    }
  }
  let candidate = samples.map(pair => pair.candidate_us)
  let upstream = samples.map(pair => pair.upstream_us)
  let cm = median(candidate)
  let rm = median(upstream)
  let cd = median(candidate.map(value => (value - cm).abs())) / cm
  let rd = median(upstream.map(value => (value - rm).abs())) / rm
  let ratio = cm / rm
  let stable = cd <= 0.05 && rd <= 0.05 && finite_positive(ratio)
  {
    "complete": true,
    "stable": stable,
    "passed": stable,
    "pairs": samples.length(),
    "candidate_median_us": cm,
    "upstream_median_us": rm,
    "candidate_mad_fraction": cd,
    "upstream_mad_fraction": rd,
    "ratio": ratio,
    "scope": "one diagnostic window; separate window drift and no general acceptance",
  }
}

///|
fn benchmark_observers(workloads : Array[FunctionalWorkload]) -> Set[String] {
  let observers : Set[String] = Set([])
  if workloads.any(row => ["gzip", "gunzip", "zcat"].contains(row.command)) {
    observers.add("gzip")
  }
  if workloads.any(row => row.other_source is Some(_)) {
    observers.add("cut")
    observers.add("sort")
  }
  observers
}

///|
async fn freeze_functional_artifacts(
  options : Map[String, String],
  workloads : Array[FunctionalWorkload],
  output : String,
) -> (Map[String, String], Array[(String, String)]) {
  let frozen = options.copy()
  let identities : Array[(String, String)] = []
  let commands : Set[String] = Set([])
  for row in workloads {
    commands.add(row.command)
  }
  let manifest_path = options
    .get("--manifest")
    .unwrap_or("tests/benchmark/real.json")
  let manifest = @json.parse(@fs.read_file(manifest_path).text())
  if real_field(manifest, "schema") == Json(3) {
    @fs.mkdir(output + "/artifacts/policy", recursive=true)
    for name in real_selected_commands(options, workloads) {
      commands.add(name)
    }
    let typed : FunctionalManifest = @json.from_json(manifest)
    let paths = [
      manifest_path,
      real_registry_path(real_text(real_field(manifest, "source_catalog"))),
      real_registry_path(real_text(real_field(manifest, "coverage_registry"))),
      typed.case_corpus,
      "tests/registry/registry.json",
      "tests/registry/case-quality.json",
      "tests/fixtures/runner/cases.json",
      "tests/benchmark/protection.json",
    ]
    for index, path in paths {
      identities.push((path, benchmark_file_sha256(path)))
      let target = output + "/artifacts/policy/" + index.to_string() + ".json"
      identities.push((target, freeze_benchmark_file(path, target)))
    }
  }
  let observers = benchmark_observers(workloads)
  let references : Set[String] = Set([])
  for row in workloads {
    references.add(row.command)
  }
  for observer in observers {
    references.add(observer)
  }
  for key in ["--wasm-root", "--baseline-wasm-root"] {
    if options.get(key) is Some(root) {
      let dest = output +
        "/artifacts/" +
        (if key == "--wasm-root" { "candidate" } else { "baseline" })
      @fs.mkdir(dest + "/cli", recursive=true)
      for command in commands {
        let source = @testkit.wasm_path(root, command)
        @fs.mkdir(dest + "/cli/" + command)
        let target = @testkit.wasm_path(dest, command)
        identities.push((target, freeze_benchmark_file(source, target)))
      }
      frozen[key] = dest
    }
  }
  for key in ["--moonrun", "--oracle-bin"] {
    if options.get(key) is Some(source) {
      let dest = output +
        "/artifacts/" +
        (if key == "--moonrun" { "runtime" } else { "oracle" })
      @fs.mkdir(dest, recursive=true)
      if key == "--moonrun" {
        let target = dest +
          "/moonrun" +
          (if @async.platform is Windows { ".exe" } else { "" })
        identities.push(
          (target, freeze_benchmark_file(source, target, executable=true)),
        )
        frozen[key] = target
      } else {
        for command in references {
          let input = source +
            "/" +
            command +
            (if @async.platform is Windows { ".exe" } else { "" })
          let target = dest +
            "/" +
            command +
            (if @async.platform is Windows { ".exe" } else { "" })
          identities.push(
            (target, freeze_benchmark_file(input, target, executable=true)),
          )
        }
        frozen[key] = dest
      }
    }
  }
  if options.get("--correctness-driver") is Some(source) {
    let target = output +
      "/artifacts/correctness-driver" +
      (if @async.platform is Windows { ".exe" } else { "" })
    identities.push(
      (target, freeze_benchmark_file(source, target, executable=true)),
    )
    frozen["--correctness-driver"] = target
  }
  write_json(output + "/artifact-identities.json", Json(identities))
  (frozen, identities)
}
