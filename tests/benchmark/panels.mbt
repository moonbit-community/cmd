///|
fn panel_number(value : Json, field : String) -> Double raise {
  guard value is Object(fields) &&
    fields.get(field) is Some(Number(number, ..)) &&
    finite_positive(number) else {
    fail("missing/invalid panel duration: " + field)
  }
  number
}

///|
fn panel_drift(a : Double, b : Double) -> Double {
  (a - b).abs() / (a / 2.0 + b / 2.0)
}

///|
fn combine_panel_windows(
  first : Json,
  second : Json,
  expected : Array[String],
  old_new : Bool,
) -> Json {
  let left = real_array(real_field(first, "rows"))
  let right = real_array(real_field(second, "rows"))
  let result : Array[Json] = []
  let mut passed = [first, second].all(report => {
      report is { "passed": True, "artifact_integrity": True, .. }
    }) &&
    !expected.is_empty() &&
    left.length() == expected.length() &&
    right.length() == expected.length()
  let seen : Set[String] = Set([])
  for id in expected {
    if seen.contains(id) {
      passed = false
    }
    seen.add(id)
    let matches = fn(row : Json) {
      row is { "workload": { "id": String(value), .. }, .. } && value == id
    }
    let a = left.filter(matches)
    let b = right.filter(matches)
    if a.length() != 1 || b.length() != 1 {
      passed = false
      result.push({
        "id": id,
        "passed": false,
        "detail": "missing or duplicate required row",
      })
      continue
    }
    let correct = [a[0], b[0]].all(row => {
        row
        is {
          "status": String("checked"),
          "probe": { "complete": True, "passed": True, .. },
          ..
        }
      }) &&
      real_field(a[0], "workload") == real_field(b[0], "workload")
    let am = real_field(a[0], "probe")
    let bm = real_field(b[0], "probe")
    let verdict : Json = try {
      let ac = panel_number(am, "candidate_median_us")
      let bc = panel_number(bm, "candidate_median_us")
      let ar = panel_number(am, "upstream_median_us")
      let br = panel_number(bm, "upstream_median_us")
      let cd = panel_drift(ac, bc)
      let rd = panel_drift(ar, br)
      let qualified = correct &&
        cd <= 0.10 &&
        rd <= 0.10 &&
        (!old_new || (ac / ar <= 1.05 && bc / br <= 1.05))
      passed = passed && qualified
      {
        "id": id,
        "passed": qualified,
        "candidate_drift": cd,
        "reference_drift": rd,
        "first_ratio": ac / ar,
        "second_ratio": bc / br,
      }
    } catch {
      error => {
        passed = false
        { "id": id, "passed": false, "detail": error.to_string() }
      }
    }
    result.push(verdict)
  }
  {
    "passed": passed,
    "rows": result,
    "required_rows": expected.length(),
    "windows": 2,
    "scope": "exact selected real-source rows; no general performance or upstream parity claim",
  }
}

///|
async fn panel_stage_root(
  root : String,
  target : String,
  commands : Set[String],
) -> String {
  @fs.mkdir(target + "/cli", recursive=true)
  for command in commands {
    @fs.mkdir(target + "/cli/" + command)
    let source = if @fs.exists(root + "/cli") {
      @testkit.wasm_path(root, command)
    } else {
      root + "/" + command + "/" + command + ".wasm"
    }
    ignore(freeze_benchmark_file(source, @testkit.wasm_path(target, command)))
  }
  target
}

///|
async fn panel_child(
  program : String,
  args : Array[String],
  log : String,
) -> Int32 {
  let capture = @process.redirect_to_file(log)
  defer capture.close()
  @process.run(program, args, stdout=capture, stderr=capture)
}

///|
async fn run_panels(options : Map[String, String]) -> Bool {
  let output = options.get("--report-dir").unwrap_or("")
  let corpus = options.get("--corpus-root").unwrap_or("")
  guard @path.Path(output).is_absolute() && @path.Path(corpus).is_absolute() else {
    fail("panels require fresh absolute report and genuine corpus roots")
  }
  for
    key in ["--wasm-root", "--moonrun", "--oracle-bin", "--correctness-driver"] {
    guard options.get(key) is Some(value) && @path.Path(value).is_absolute() else {
      fail("panels require explicit absolute " + key)
    }
  }
  guard !options.contains("--probe-pairs") && !options.contains("--window") else {
    fail("unified panels fix two windows of nine measured pairs")
  }
  let rows = functional_inventory(options)
  let manifest_path = options
    .get("--manifest")
    .unwrap_or("tests/benchmark/real.json")
  let original = @json.parse(@fs.read_file(manifest_path).text())
  guard original is Object(fields) && real_field(original, "schema") == Json(3) else {
    fail("all new panels use the unified real-corpus schema3 manifest")
  }
  @fs.mkdir(output, recursive=true, allow_exist=false)
  @fs.mkdir(output + "/tools/oracle", recursive=true)
  let fixed : Array[(String, String)] = []
  @fs.mkdir(output + "/policy/tests/registry", recursive=true)
  @fs.mkdir(output + "/policy/tests/benchmark", recursive=true)
  let actual = options.copy()
  let commands = real_selected_commands(options, rows)
  actual["--wasm-root"] = panel_stage_root(
    options["--wasm-root"],
    output + "/input-candidate",
    commands,
  )
  if options.get("--baseline-wasm-root") is Some(root) {
    actual["--baseline-wasm-root"] = panel_stage_root(
      root,
      output + "/input-baseline",
      commands,
    )
  }
  for
    (key, name) in [
      ("--moonrun", "moonrun"),
      ("--correctness-driver", "correctness-driver"),
    ] {
    let target = output +
      "/tools/" +
      name +
      (if @async.platform is Windows { ".exe" } else { "" })
    fixed.push(
      (target, freeze_benchmark_file(options[key], target, executable=true)),
    )
    actual[key] = target
  }
  let program = output +
    "/tools/benchmark" +
    (if @async.platform is Windows { ".exe" } else { "" })
  fixed.push(
    (
      program,
      freeze_benchmark_file(
        @fs.realpath(@env.args()[0]),
        program,
        executable=true,
      ),
    ),
  )
  let references : Set[String] = Set([])
  for row in rows {
    references.add(row.command)
  }
  for name in benchmark_observers(rows) {
    references.add(name)
  }
  for name in references {
    let suffix = "/" +
      name +
      (if @async.platform is Windows { ".exe" } else { "" })
    let source = options["--oracle-bin"] + suffix
    fixed.push(
      (
        output + "/tools/oracle" + suffix,
        freeze_benchmark_file(
          source,
          output + "/tools/oracle" + suffix,
          executable=true,
        ),
      ),
    )
  }
  actual["--oracle-bin"] = output + "/tools/oracle"
  let frozen = fields.copy()
  for
    (field, name) in [
      ("source_catalog", "sources.json"),
      ("coverage_registry", "coverage.json"),
    ] {
    let source = real_registry_path(real_text(real_field(original, field)))
    let target = output + "/" + name
    fixed.push((target, freeze_benchmark_file(source, target)))
    frozen[field] = Json(target)
  }
  let manifest : FunctionalManifest = @json.from_json(original)
  let cases = @testkit.load_cases(manifest.case_corpus)
  let case_path = output + "/cases.json"
  let command_catalog = @json.parse(
    @fs.read_file("tests/fixtures/runner/cases.json").text(),
  )
  write_json(case_path, {
    "schema": 2,
    "commands": real_field(command_catalog, "commands"),
    "cases": Json(cases),
  })
  for
    path in [
      "tests/registry/registry.json", "tests/registry/case-quality.json", "tests/benchmark/protection.json",
    ] {
    fixed.push((path, benchmark_file_sha256(path)))
    fixed.push(
      (
        output + "/policy/" + path,
        freeze_benchmark_file(path, output + "/policy/" + path),
      ),
    )
  }
  fixed.push((case_path, benchmark_file_sha256(case_path)))
  frozen["case_corpus"] = Json(case_path)
  let frozen_manifest = output + "/manifest.json"
  write_json(frozen_manifest, Json(frozen))
  fixed.push((frozen_manifest, benchmark_file_sha256(frozen_manifest)))
  for key in ["--wasm-root", "--baseline-wasm-root"] {
    if actual.get(key) is Some(root) {
      for command in commands {
        let file = @testkit.wasm_path(root, command)
        fixed.push((file, benchmark_file_sha256(file)))
      }
    }
  }
  let windows : Array[Json] = []
  let statuses : Array[Int32] = []
  for window in 0..<2 {
    let target = output + "/window-" + window.to_string()
    let args = [
      "probe",
      "--manifest",
      frozen_manifest,
      "--wasm-root",
      actual["--wasm-root"],
      "--moonrun",
      actual["--moonrun"],
      "--correctness-driver",
      actual["--correctness-driver"],
      "--oracle-bin",
      actual["--oracle-bin"],
      "--corpus-root",
      corpus,
      "--report-dir",
      target,
      "--probe-pairs",
      "9",
      "--window",
      window.to_string(),
    ]
    if options.get("--commands") is Some(names) {
      args.append(["--commands", names])
    }
    if actual.get("--baseline-wasm-root") is Some(root) {
      args.append(["--baseline-wasm-root", root])
    }
    statuses.push(panel_child(program, args, target + ".log"))
    windows.push(
      if @fs.exists(target + "/report.json") {
        @json.parse(@fs.read_file(target + "/report.json").text())
      } else {
        Json::null()
      },
    )
    write_json(output + "/panels.json", {
      "passed": false,
      "complete": false,
      "completed_windows": windows.length(),
      "exit_statuses": Json(statuses),
    })
  }
  let combined = combine_panel_windows(
    windows[0],
    windows[1],
    rows.map(row => row.id),
    actual.contains("--baseline-wasm-root"),
  )
  let mut intact = true
  for (path, expected) in fixed {
    if benchmark_file_sha256(path) != expected {
      intact = false
    }
  }
  let passed = statuses.all(status => status == 0) &&
    combined is { "passed": True, .. } &&
    intact
  write_json(output + "/artifact-identities.json", Json(fixed))
  write_json(output + "/panels.json", {
    "schema": 3,
    "passed": passed,
    "complete": true,
    "artifact_integrity": intact,
    "windows": 2,
    "comparison": combined,
    "required_workloads": rows.length(),
    "commands": Json(commands.to_array()),
    "exit_statuses": Json(statuses),
    "scope": "one data-driven real-corpus suite; independent local contracts precede each timing window; no command-specific runner or synthetic timing input",
    "general_performance_acceptance": false,
    "upstream_parity": false,
    "blind_holdout": false,
  })
  passed
}
