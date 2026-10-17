///|
struct TestIndex {
  index : Int32
  name : String
  attrs : Array[Json]
} derive(FromJson)

///|
struct TestOutline {
  tests : Map[String, Array[TestIndex]]
} derive(FromJson)

///|
fn exact_test_index(
  outline : Json,
  file : String,
  name : String,
) -> Int32 raise {
  let outline : TestOutline = @json.from_json(outline)
  let parts = file.split("/").collect()
  let basename = parts[parts.length() - 1].to_owned()
  guard outline.tests.get(basename) is Some(tests) else {
    fail("compiled test outline does not contain source file: " + file)
  }
  let matches = tests.filter(item => item.name == name)
  guard matches.length() == 1 else {
    fail("compiled test outline requires exactly one named test: " + name)
  }
  let selected = matches[0]
  guard selected.index >= 0 &&
    tests.filter(item => item.index == selected.index).length() == 1 else {
    fail("compiled test outline has an invalid or ambiguous index")
  }
  // --index includes skipped tests. Unknown attributes must therefore fail
  // closed rather than silently turning a skipped declaration into coverage.
  guard selected.attrs.is_empty() else {
    fail("attributed tests require explicit adapter support: " + name)
  }
  selected.index
}

///|
fn single_test_passed(result : @testkit.RunResult) -> Bool {
  if result.status != 0 {
    return false
  }
  let summaries : Array[String] = []
  for stream in [result.stdout, result.stderr] {
    let decoded = @utf8.decode(stream) catch { _ => return false }
    for line in @testkit.normalize_lf(decoded).split("\n") {
      let line = line.trim().to_owned()
      if line.has_prefix("Total tests:") {
        summaries.push(line)
      }
    }
  }
  summaries == ["Total tests: 1, passed: 1, failed: 0."]
}

///|
// Package assertions expose their completion status. Driver streams are kept
// and paired, but are not substitutes for command stdout or filesystem probes.
fn package_observations(
  passed : Bool,
  required : ArrayView[String],
) -> (Array[String], Array[String]) {
  let observed = if passed { ["status"] } else { [] }
  (observed, required.filter(dimension => !observed.contains(dimension)))
}

///|
fn platform_applies(platforms : ArrayView[String], host : String) -> Bool {
  platforms.is_empty() ||
  platforms.contains(host) ||
  (platforms.contains("posix") && ["linux", "macos"].contains(host))
}

///|
fn package_selected(file : String, package_path : String) -> Bool {
  @path.Path(file).dirname().to_string() == package_path
}

///|
async fn package_artifacts(file : String, backend : String) -> (String, String) {
  let package_path = @path.Path(file).dirname().to_string()
  let mut module_root = package_path
  while !@fs.exists(module_root + "/moon.mod") {
    let parent = @path.Path(module_root).dirname().to_string()
    guard parent != module_root && parent != "." else {
      fail("cannot find module for registered source: " + file)
    }
    module_root = parent
  }
  let mut module_name = ""
  for line in @fs.read_file(module_root + "/moon.mod").text().split("\n") {
    let parts = line.split("=").collect()
    if parts.length() == 2 && parts[0].trim() == "name" {
      guard @json.parse(parts[1].trim().to_owned()) is String(name) else {
        fail("module name must be an explicit string: " + module_root)
      }
      module_name = name
    }
    if parts.length() == 2 && parts[0].trim() == "source" {
      fail(
        "module source remapping requires explicit adapter support: " +
        module_root,
      )
    }
  }
  guard @testkit.safe_relative_path(module_name) else {
    fail("invalid module name")
  }
  let relative = package_path.strip_prefix(module_root).unwrap().to_owned()
  let directory = "_build/" + backend + "/debug/test/" + module_name + relative
  let parts = (module_name + relative).split("/").collect()
  let package_name = parts[parts.length() - 1].to_owned()
  let kind = if file.has_suffix("_wbtest.mbt") {
    "whitebox"
  } else {
    "blackbox"
  }
  let extension = if backend == "native" { "exe" } else { "wasm" }
  (
    directory + "/__" + kind + "_test_info.json",
    directory + "/" + package_name + "." + kind + "_test." + extension,
  )
}

///|
async fn source_records(directory : String, records : Array[Json]) -> Unit {
  for name in @fs.readdir(directory, sort=true) {
    if name.has_prefix(".") || name == "_build" || name == "target" {
      continue
    }
    let path = directory + "/" + name
    match @fs.kind(path, follow_symlink=false) {
      Directory => source_records(path, records)
      Regular if name.has_suffix(".mbt") ||
        name.has_suffix(".mbtx") ||
        name.has_suffix(".json") ||
        name == "moon.mod" ||
        name == "moon.pkg" => {
        let hash = @testkit.file_digest(path)
        guard hash != "" else { fail("cannot fingerprint source: " + path) }
        records.push({ "path": Json(path), "sha256": Json(hash) })
      }
      _ => ()
    }
  }
}

///|
async fn source_corpus() -> Json {
  let records : Array[Json] = []
  for directory in ["commands", "core", "tests"] {
    source_records(directory, records)
  }
  let workspace_hash = @testkit.file_digest("moon.work")
  guard workspace_hash != "" else { fail("cannot fingerprint moon.work") }
  records.push({ "path": "moon.work", "sha256": Json(workspace_hash) })
  {
    "schema": 1,
    "kind": "package-test-source-corpus",
    "sources": Json(records),
  }
}

///|
async fn capture_moon(
  args : Array[String],
  prefix : String,
) -> @testkit.TimedRun {
  @fs.write_file(
    prefix + ".invocation.json",
    @testkit.canonical_json({
      "program": "moon",
      "args": Json(args),
      "timeout_ms": 120000,
      "environment": "inherited",
    }),
  )
  let result = @testkit.run_with_deadline(
    "moon",
    args,
    120000,
    stdin=b"",
    inherit_env=true,
  )
  @fs.write_file(prefix + ".stdout.bin", result.output.stdout)
  @fs.write_file(prefix + ".stderr.bin", result.output.stderr)
  @fs.write_file(
    prefix + ".result.json",
    @testkit.canonical_json({
      "status": Json(result.output.status),
      "timed_out": Json(result.timed_out),
      "cleanup_error": Json(result.cleanup_error),
    }),
  )
  result
}

///|
fn require_completed(result : @testkit.TimedRun, stage : String) -> Unit raise {
  if result.cleanup_error is Some(error) {
    fail(stage + " cleanup failed: " + error)
  }
  guard !result.timed_out else {
    fail(stage + " deadline expired; captured streams are partial")
  }
}

///|
async fn execute_package_test(
  entry : @registry.RegistryEntry,
  backend : String,
  directory : String,
) -> @testkit.CaseReport {
  let started = @async.now()
  let host = @testkit.host_platform()
  let base : @testkit.CaseReport = {
    id: entry.behavior_id,
    command: entry.command,
    result: "skip",
    verification: "contract",
    stage: "platform",
    detail: "case excludes " + host,
    platform: host,
    backend,
    source_version: "workspace",
    duration_ms: 0L,
    observations: [],
    missing_observations: entry.observations,
    evidence: None,
  }
  if !platform_applies(entry.platforms, host) {
    return base
  }
  if !entry.required_backends.contains(backend) {
    return { ..base, stage: "backend", detail: "case excludes " + backend, }
  }
  let evidence = directory +
    "/cases/" +
    @testkit.sha256_text(entry.behavior_id) +
    "/" +
    backend
  let mut stage = "binding"
  try {
    guard entry.binding() is PackageTest(file~, name~) else {
      fail("expected package-test binding")
    }
    guard @testkit.safe_relative_path(file) else {
      fail("unsafe registered source path")
    }
    @fs.mkdir(evidence, recursive=true)
    @fs.write_file(
      evidence + "/binding.json",
      @testkit.canonical_json({
        "id": Json(entry.behavior_id),
        "source": Json(file),
        "test_name": Json(name),
        "backend": Json(backend),
        "platform": Json(host),
      }),
    )
    stage = "build"
    let common = [
      "test", "--target", backend, "--deny-warn", "--no-parallelize", file,
    ]
    let built = capture_moon([..common, "--build-only"], evidence + "/build")
    require_completed(built, stage)
    guard built.output.status == 0 else {
      fail("package-test build exited with status \{built.output.status}")
    }
    stage = "test-index"
    let (index_path, artifact_path) = package_artifacts(file, backend)
    let outline_bytes = @fs.read_file(index_path).binary()
    let index = exact_test_index(
      @json.parse(@utf8.decode(outline_bytes)),
      file,
      name,
    )
    @fs.write_file(evidence + "/test-info.json", outline_bytes)
    let artifact = @fs.read_file(artifact_path).binary()
    let artifact_hash = @testkit.sha256_bytes(artifact)
    let artifacts = directory + "/artifacts/" + backend
    @fs.mkdir(artifacts, recursive=true, allow_exist=true)
    let extension = if backend == "native" { ".exe" } else { ".wasm" }
    let frozen_artifact = artifacts +
      "/" +
      @testkit.sha256_text(file) +
      extension
    if @fs.exists(frozen_artifact) {
      guard @testkit.file_digest(frozen_artifact) == artifact_hash else {
        fail("test artifact changed within run")
      }
    } else {
      @fs.write_file(frozen_artifact, artifact)
    }
    @fs.write_file(
      evidence + "/artifact.json",
      @testkit.canonical_json({
        "source": Json(artifact_path),
        "frozen": Json(frozen_artifact),
        "sha256": Json(artifact_hash),
        "test_index": Json(index),
      }),
    )
    stage = "test"
    let executed = capture_moon(
      [..common, "--index", index.to_string()],
      evidence + "/test",
    )
    require_completed(executed, stage)
    stage = "source-stability"
    guard @testkit.file_digest(artifact_path) == artifact_hash &&
      @testkit.file_digest(index_path) == @testkit.sha256_bytes(outline_bytes) else {
      fail("test artifact or named index changed during execution")
    }
    let passed = single_test_passed(executed.output)
    let (observed, missing) = package_observations(passed, entry.observations)
    {
      ..base,
      result: if passed && missing.is_empty() {
        "pass"
      } else {
        "fail"
      },
      stage: if passed && missing.is_empty() {
        "complete"
      } else {
        "assertion"
      },
      detail: if passed {
        "exact named test executed once and passed"
      } else {
        "expected exactly one executed and passed test; inspect captured output"
      },
      duration_ms: @async.now() - started,
      observations: observed,
      missing_observations: missing,
      evidence: Some(evidence),
    }
  } catch {
    error =>
      {
        ..base,
        result: "infra",
        stage,
        detail: error.to_string(),
        duration_ms: @async.now() - started,
        evidence: Some(evidence),
      }
  }
}

///|
fn package_pair_differences(
  native : @testkit.RunResult,
  wasm : @testkit.RunResult,
) -> Array[String] {
  let differences : Array[String] = []
  if !single_test_passed(native) || !single_test_passed(wasm) {
    differences.push("each backend must execute exactly one passing named test")
  }
  if native.status != wasm.status {
    differences.push("test process status differs")
  }
  if native.stdout != wasm.stdout {
    differences.push("test process stdout differs")
  }
  if native.stderr != wasm.stderr {
    differences.push("test process stderr differs")
  }
  differences
}

///|
async fn package_test_capture(directory : String) -> @testkit.RunResult {
  guard @json.parse(@fs.read_file(directory + "/test.result.json").text())
    is {
      "status": Number(status, ..),
      "timed_out": False,
      "cleanup_error": Null,
      ..
    } else {
    fail("package pair requires completed execution captures")
  }
  {
    status: status.to_int(),
    stdout: @fs.read_file(directory + "/test.stdout.bin").binary(),
    stderr: @fs.read_file(directory + "/test.stderr.bin").binary(),
  }
}

///|
async fn execute_package_pair(
  entry : @registry.RegistryEntry,
  directory : String,
) -> Array[@testkit.CaseReport] {
  let started = @async.now()
  let native = execute_package_test(entry, "native", directory)
  let wasm = execute_package_test(entry, "wasm", directory)
  let pair : @testkit.CaseReport = {
    ..native,
    verification: "backend-pair",
    backend: "native+wasm",
    duration_ms: @async.now() - started,
    evidence: Some(
      directory + "/cases/" + @testkit.sha256_text(entry.behavior_id),
    ),
    observations: [],
    missing_observations: entry.observations,
  }
  if native.result != "pass" || wasm.result != "pass" {
    return [
      native,
      wasm,
      {
        ..pair,
        result: if native.result == "infra" || wasm.result == "infra" {
          "infra"
        } else if native.result == "skip" || wasm.result == "skip" {
          "skip"
        } else {
          "fail"
        },
        stage: "backend-contract",
        detail: "native=" + native.result + "; wasm=" + wasm.result,
      },
    ]
  }
  let compared = try {
    let differences = package_pair_differences(
      package_test_capture(native.evidence.unwrap()),
      package_test_capture(wasm.evidence.unwrap()),
    )
    let (observed, missing) = package_observations(
      differences.is_empty(),
      entry.observations,
    )
    {
      ..pair,
      result: if differences.is_empty() && missing.is_empty() {
        "pass"
      } else {
        "fail"
      },
      stage: if differences.is_empty() && missing.is_empty() {
        "complete"
      } else {
        "backend-comparison"
      },
      detail: if differences.is_empty() {
        "exact named test process status and complete output bytes agree across Native and Wasm"
      } else {
        differences.join("; ")
      },
      observations: observed,
      missing_observations: missing,
    }
  } catch {
    error =>
      {
        ..pair,
        result: "infra",
        stage: "backend-comparison",
        detail: error.to_string(),
      }
  }
  [native, wasm, compared]
}
