///|
async fn invocation(
  name : String,
  backend : String,
  args : Array[String],
  evidence : String,
  probe : String,
) -> @testkit.RunResult {
  let root = "_build/" + backend + "/release/build"
  let completed = @testkit.run_with_deadline(
    if backend == "wasm" {
      "moonrun"
    } else {
      @testkit.executable_path(root, name)
    },
    if backend == "wasm" {
      [@testkit.wasm_path(root, name), "--", ..args]
    } else {
      args
    },
    15000,
    stdin=b"",
  )
  @fs.write_file(
    evidence + "/" + probe + ".stdout.bin",
    completed.output.stdout,
  )
  @fs.write_file(
    evidence + "/" + probe + ".stderr.bin",
    completed.output.stderr,
  )
  @fs.write_file(
    evidence + "/" + probe + ".status.txt",
    completed.output.status.to_string(),
  )
  if completed.cleanup_error is Some(error) {
    fail("metadata child cleanup: " + error)
  }
  guard !completed.timed_out else {
    fail("metadata probe deadline expired: " + probe)
  }
  completed.output
}

///|
async fn metadata_report(
  name : String,
  backend : String,
  directory : String,
  retain_success~ : Bool = false,
) -> @testkit.CaseReport {
  let started = @async.now()
  let evidence = directory + "/" + name
  let base : @testkit.CaseReport = {
    id: "metadata:" + name,
    command: name,
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: @testkit.host_platform(),
    backend,
    source_version: "workspace",
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    evidence: Some(evidence),
  }
  try {
    @fs.mkdir(evidence)
    let manifest_text = @fs.read_file("commands/" + name + "/moon.mod").text()
    let mut version = ""
    for line in manifest_text.split("\n") {
      let normalized = line.trim()
      if normalized.has_prefix("version = \"") {
        version = normalized
          .strip_prefix("version = \"")
          .unwrap()
          .strip_suffix("\"")
          .unwrap()
          .to_owned()
      }
    }
    guard version != "" else { fail("missing version for " + name) }
    let help = invocation(name, backend, ["--help"], evidence, "help")
    let help_text = @utf8.decode(help.stdout)
    let help_ok = help.status == 0 &&
      help.stderr == b"" &&
      help_text.has_prefix("Usage: " + name) &&
      help_text.has_suffix("\n") &&
      help_text.contains("--help") &&
      help_text.contains("--version") &&
      help_text.contains("display this help and exit") &&
      help_text.contains("display version and exit") &&
      !help_text.contains("Show this help") &&
      !help_text.contains("Show version") &&
      !help_text.contains("package version") &&
      !help_text.contains("output version information")
    let actual_version = invocation(
      name,
      backend,
      ["--version"],
      evidence,
      "version",
    )
    let expected = @utf8.encode(name + " " + version + "\n")
    let mut version_ok = actual_version.status == 0 &&
      actual_version.stderr == b"" &&
      actual_version.stdout == expected
    if [
        "cksum", "column", "csplit", "date", "diff", "env", "fmt", "fold", "gunzip",
        "gzip", "hexdump", "md5sum", "od", "patch", "realpath", "sed", "seq", "sha1sum",
        "sha512sum", "split", "strings", "tree", "unlink", "which", "zcat",
      ].contains(name) {
      let combined = invocation(
        name,
        backend,
        ["--version", "metadata-unused-operand"],
        evidence,
        "combined-version",
      )
      version_ok = version_ok &&
        combined.status == 0 &&
        combined.stderr == b"" &&
        combined.stdout == expected
    }
    if name == "hexdump" {
      let alias_result = invocation(
        name,
        backend,
        ["-V"],
        evidence,
        "version-alias",
      )
      version_ok = version_ok &&
        alias_result.status == 0 &&
        alias_result.stderr == b"" &&
        alias_result.stdout == expected
    }
    if help_ok && version_ok && !retain_success {
      @fs.rmdir(evidence, recursive=true)
    }
    {
      ..base,
      result: if help_ok && version_ok {
        "pass"
      } else {
        "fail"
      },
      stage: if help_ok && version_ok {
        "complete"
      } else {
        "assertion"
      },
      detail: "help=\{help_ok} version=\{version_ok}",
      duration_ms: @async.now() - started,
      observations: ["status", "stdout", "stderr"],
      evidence: if help_ok && version_ok && !retain_success {
        None
      } else {
        Some(evidence)
      },
    }
  } catch {
    error =>
      {
        ..base,
        result: "infra",
        stage: "metadata-probe",
        detail: error.to_string(),
        duration_ms: @async.now() - started,
      }
  }
}

///|
fn metadata_pair_differences(
  native : Map[String, Bytes],
  wasm : Map[String, Bytes],
) -> Array[String] {
  let failures : Array[String] = []
  for
    required in [
      "help.stdout.bin", "help.stderr.bin", "help.status.txt", "version.stdout.bin",
      "version.stderr.bin", "version.status.txt",
    ] {
    if !native.contains(required) || !wasm.contains(required) {
      failures.push("missing probe observation: " + required)
    }
  }
  let names = native.keys().collect()
  for name in wasm.keys() {
    if !names.contains(name) {
      names.push(name)
    }
  }
  names.sort()
  for name in names {
    if native.get(name) != wasm.get(name) {
      failures.push("backend observation differs: " + name)
    }
  }
  failures
}

///|
async fn metadata_captures(directory : String) -> Map[String, Bytes] {
  let captures : Map[String, Bytes] = Map([])
  for name in @fs.readdir(directory, sort=true) {
    if name.has_suffix(".stdout.bin") ||
      name.has_suffix(".stderr.bin") ||
      name.has_suffix(".status.txt") {
      captures[name] = @fs.read_file(directory + "/" + name).binary()
    }
  }
  captures
}

///|
async fn metadata_pair_reports(
  name : String,
  directory : String,
) -> Array[@testkit.CaseReport] {
  let started = @async.now()
  let native = metadata_report(
    name,
    "native",
    directory + "/native",
    retain_success=true,
  )
  let wasm = metadata_report(
    name,
    "wasm",
    directory + "/wasm",
    retain_success=true,
  )
  let pair : @testkit.CaseReport = {
    ..native,
    verification: "backend-pair",
    backend: "native+wasm",
    evidence: Some(directory),
    observations: [],
    missing_observations: ["status", "stdout", "stderr"],
    duration_ms: @async.now() - started,
  }
  if native.result != "pass" || wasm.result != "pass" {
    return [
      native,
      wasm,
      {
        ..pair,
        result: if native.result == "infra" || wasm.result == "infra" {
          "infra"
        } else {
          "fail"
        },
        stage: "backend-contract",
        detail: "native=" + native.result + "; wasm=" + wasm.result,
      },
    ]
  }
  let differences = metadata_pair_differences(
    metadata_captures(directory + "/native/" + name),
    metadata_captures(directory + "/wasm/" + name),
  )
  [
    native,
    wasm,
    {
      ..pair,
      result: if differences.is_empty() {
        "pass"
      } else {
        "fail"
      },
      stage: if differences.is_empty() {
        "complete"
      } else {
        "backend-comparison"
      },
      detail: if differences.is_empty() {
        "Native and Wasm help/version probe statuses and complete output bytes agree"
      } else {
        differences.join("; ")
      },
      observations: ["status", "stdout", "stderr"],
      missing_observations: [],
    },
  ]
}

///|
async fn main {
  @testkit.begin_environment_capture()
  let args = @env.args()[1:]
  let backend = args.get(0).unwrap_or("native")
  guard ["native", "wasm", "pair"].contains(backend) else {
    fail("expected native, wasm or pair backend")
  }
  let started = @async.now()
  let mut directory = "test-reports/metadata-" +
    backend +
    "-" +
    started.to_string()
  let mut list = false
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--list" => list = true
      "--report-dir" => {
        index += 1
        guard args.get(index) is Some(value) else {
          fail("--report-dir requires a path")
        }
        directory = value
      }
      _ => fail("unknown metadata option: " + args[index])
    }
    index += 1
  }
  let registry = @registry.load("tests/registry/registry.json")
  let errors = @registry.validate(registry)
  errors.append(@registry.validate_source_bindings(registry))
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let names = registry.entries
    .filter(entry => {
      entry.implementation == "metadata-probe" &&
      (if backend == "pair" {
        entry.requires_backend_pair()
      } else {
        entry.required_backends.contains(backend)
      })
    })
    .map(entry => entry.command)
  names.sort()
  guard !names.is_empty() else { fail("no registered metadata probes") }
  if list {
    for name in names {
      println(name)
    }
    return
  }
  guard !@fs.exists(directory) else {
    fail("report directory already exists: " + directory)
  }
  @fs.mkdir(directory, recursive=true)
  if backend == "pair" {
    @fs.mkdir(directory + "/native")
    @fs.mkdir(directory + "/wasm")
  }
  let start_metadata = @testkit.collect_run_metadata(
    "metadata-" + backend + "-" + started.to_string(),
    manifest_path="tests/registry/registry.json",
    case_corpus_path="tests/registry/registry.json",
    registry_path="tests/registry/registry.json",
    native_root="_build/native/release/build",
    wasm_root="_build/wasm/release/build",
    started_at_ms=started,
    ended_at_ms=started,
  )
  let reports : Array[@testkit.CaseReport] = []
  for name in names {
    if backend == "pair" {
      reports.append(metadata_pair_reports(name, directory))
    } else {
      reports.push(metadata_report(name, backend, directory))
    }
  }
  let metadata = @testkit.collect_run_metadata(
    "metadata-" + backend + "-" + started.to_string(),
    manifest_path="tests/registry/registry.json",
    case_corpus_path="tests/registry/registry.json",
    registry_path="tests/registry/registry.json",
    native_root="_build/native/release/build",
    wasm_root="_build/wasm/release/build",
    started_at_ms=started,
    ended_at_ms=@async.now(),
  )
  let metadata = @testkit.finalize_run_metadata(start_metadata, metadata)
  @testkit.write_reports_with_metadata(directory, reports, metadata)
  let failures = reports.filter(row => row.result != "pass")
  for row in failures {
    println(row.id + ": " + row.detail)
  }
  println(
    "metadata (\{backend}): \{reports.length() - failures.length()}/\{reports.length()} evidence rows passed; report: \{directory}",
  )
  if !failures.is_empty() || metadata.reproducibility_status != "complete" {
    @sys.exit(1)
  }
}
