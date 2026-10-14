///|
fn pair_report(
  fixture : @testkit.Case,
  result : String,
  stage : String,
  detail : String,
  duration : Int64,
  evidence : String?,
) -> @testkit.CaseReport {
  {
    id: fixture.id,
    command: fixture.command,
    result,
    verification: "backend-pair",
    stage,
    detail,
    platform: @testkit.host_platform(),
    backend: "native+wasm",
    source_version: fixture.source_version.unwrap_or("workspace"),
    duration_ms: duration,
    observations: if result == "pass" {
      ["status", "stdout", "stderr", ..@testkit.contract_observations(fixture)]
    } else {
      []
    },
    missing_observations: if result == "infra" {
      fixture.observe.unwrap_or([])
    } else {
      []
    },
    evidence,
  }
}

///|
async fn execute_backend_pair(
  fixture : @testkit.Case,
  native_root : String,
  wasm_root : String,
  report_dir : String,
  http_base? : String,
) -> @testkit.CaseReport {
  let start = @async.now()
  execute_backend_pair_inner(
    fixture,
    native_root,
    wasm_root,
    report_dir,
    http_base?,
  ) catch {
    error =>
      pair_report(
        fixture,
        "infra",
        "backend-pair-infrastructure",
        error.to_string(),
        @async.now() - start,
        Some(report_dir + "/backend-pair/" + fixture.id),
      )
  }
}

///|
async fn execute_backend_pair_inner(
  fixture : @testkit.Case,
  native_root : String,
  wasm_root : String,
  report_dir : String,
  http_base? : String,
) -> @testkit.CaseReport {
  let start = @async.now()
  if !fixture.platform_applies() {
    return pair_report(
      fixture,
      "skip",
      "platform",
      "case excludes " + @testkit.host_platform(),
      @async.now() - start,
      None,
    )
  }
  if fixture.expected_rejection is Some(_) {
    return pair_report(
      fixture,
      "infra",
      "selection",
      "backend pairing is only defined for supported contracts",
      @async.now() - start,
      None,
    )
  }
  let pair_root = report_dir + "/backend-pair/" + fixture.id
  if @fs.exists(pair_root) {
    return pair_report(
      fixture,
      "infra",
      "evidence",
      "evidence already exists: " + pair_root,
      @async.now() - start,
      Some(pair_root),
    )
  }
  @fs.mkdir(pair_root, recursive=true)
  let native = @testkit.execute_contract(
    fixture,
    native_root,
    false,
    pair_root + "/native",
    http_base?,
    retain_success=true,
  )
  let wasm = @testkit.execute_contract(
    fixture,
    wasm_root,
    true,
    pair_root + "/wasm",
    http_base?,
    retain_success=true,
  )
  if native.result == "infra" || wasm.result == "infra" {
    return pair_report(
      fixture,
      "infra",
      "backend-pair",
      "native=" +
      native.result +
      " " +
      native.detail +
      "; wasm=" +
      wasm.result +
      " " +
      wasm.detail,
      @async.now() - start,
      Some(pair_root),
    )
  }
  if native.result != "pass" || wasm.result != "pass" {
    return pair_report(
      fixture,
      "fail",
      "backend-pair",
      "native=" +
      native.result +
      " " +
      native.detail +
      "; wasm=" +
      wasm.result +
      " " +
      wasm.detail,
      @async.now() - start,
      Some(pair_root),
    )
  }
  let native_root = pair_root + "/native/" + fixture.id
  let wasm_root = pair_root + "/wasm/" + fixture.id
  let native_stdout = pair_stream(
    fixture,
    @fs.read_file(native_root + "/stdout.bin").binary(),
    "stdout",
    native_root + "/work",
  )
  let wasm_stdout = pair_stream(
    fixture,
    @fs.read_file(wasm_root + "/stdout.bin").binary(),
    "stdout",
    wasm_root + "/work",
  )
  let native_stderr = pair_stream(
    fixture,
    @fs.read_file(native_root + "/stderr.bin").binary(),
    "stderr",
    native_root + "/work",
  )
  let wasm_stderr = pair_stream(
    fixture,
    @fs.read_file(wasm_root + "/stderr.bin").binary(),
    "stderr",
    wasm_root + "/work",
  )
  let native_snapshot = @fs.read_file(native_root + "/snapshot.txt").text()
  let wasm_snapshot = @fs.read_file(wasm_root + "/snapshot.txt").text()
  let differences : Array[String] = []
  if @fs.read_file(native_root + "/status.txt").text() !=
    @fs.read_file(wasm_root + "/status.txt").text() {
    differences.push("status differs")
  }
  let stdout_equal = if fixture.stdout_order == Some("lines") {
    @testkit.unordered_lines_equal(native_stdout, wasm_stdout)
  } else {
    @testkit.bytes_equal(native_stdout, wasm_stdout)
  }
  if !stdout_equal {
    differences.push("stdout differs")
  }
  if !@testkit.bytes_equal(native_stderr, wasm_stderr) {
    differences.push("stderr differs")
  }
  if native_snapshot != wasm_snapshot {
    differences.push("filesystem observations differ")
  }
  if differences.is_empty() {
    @fs.rmdir(pair_root, recursive=true)
    pair_report(
      fixture,
      "pass",
      "complete",
      "Native and Wasm outputs and observations agree",
      @async.now() - start,
      None,
    )
  } else {
    pair_report(
      fixture,
      "fail",
      "assertion",
      differences.join("; "),
      @async.now() - start,
      Some(pair_root),
    )
  }
}

///|
// Contract outputs containing ${WORK} already assert each execution's exact
// fixture root. Compare that declared placeholder across isolated directories.
fn pair_stream(
  fixture : @testkit.Case,
  data : Bytes,
  field : String,
  root : String,
) -> Bytes {
  let expected = if field == "stdout" {
    fixture.expected_stdout_text
  } else {
    fixture.expected_stderr_text
  }
  let rules = fixture.normalizations.copy()
  if expected is Some(value) && value.contains("${WORK}") {
    rules.push({
      field,
      rule: "temporary-path",
      comment: "Declared ${WORK} output placeholder.",
    })
  }
  @testkit.normalize_text(data, field, rules, root)
}

///|
// Only values allocated by the scenario harness are rewritten. Product output,
// diagnostics and file bytes otherwise retain their exact representation.
fn scenario_pair_bytes(data : Bytes, work : String, origin : String?) -> Bytes {
  let text = @utf8.decode(data) catch { _ => return data }
  let mut normalized = text.replace_all(old=work, new="${WORK}")
  if origin is Some(origin) {
    normalized = normalized.replace_all(old=origin, new="${HTTP_BASE}")
    let authority = origin
      .strip_prefix("http://")
      .unwrap_or(origin[:])
      .to_owned()
    normalized = normalized.replace_all(old=authority, new="${HTTP_AUTHORITY}")
    let localhost = authority.replace_all(old="127.0.0.1", new="localhost")
    normalized = normalized.replace_all(old=localhost, new="${HTTP_LOCALHOST}")
  }
  @utf8.encode(normalized)
}

///|
async fn scenario_pair_snapshot(
  evidence : String,
  fixture : @testkit.Case,
) -> String {
  let work = evidence + "/work"
  let origin_path = evidence + "/network-origin.txt"
  let origin = if @fs.exists(origin_path) {
    Some(@fs.read_file(origin_path).text())
  } else {
    None
  }
  // Inode identity is compared as within-fixture alias classes by snapshot().
  // Wall-clock timestamps belong to before/after assertions in the scenario;
  // independent fixture creation times are deliberately not equality evidence.
  let observe : Array[String] = if fixture.id == "filesystem-fidelity" {
    ["mode", "identity", "symlink-target"]
  } else {
    []
  }
  let normalized = @testkit.snapshot(evidence, observe~).map(item => {
    let metadata : Map[String, String] = Map([])
    for key, value in item.metadata {
      metadata[key] = @utf8.decode(
        scenario_pair_bytes(@utf8.encode(value), work, origin),
      ) catch {
        _ => value
      }
    }
    {
      ..item,
      content: scenario_pair_bytes(item.content, work, origin),
      metadata,
    }
  })
  @testkit.snapshot_fingerprint(normalized)
}

///|
async fn execute_scenario_backend_pair(
  fixture : @testkit.Case,
  native_root : String,
  wasm_root : String,
  report_dir : String,
) -> @testkit.CaseReport {
  let started = @async.now()
  let pair_root = report_dir + "/backend-pair/" + fixture.id
  let base = {
    ..pair_report(
      fixture,
      "infra",
      "backend-pair-infrastructure",
      "",
      0L,
      Some(pair_root),
    ),
    id: "scenario:" + fixture.id,
  }
  if !fixture.platform_applies() {
    return {
      ..base,
      result: "skip",
      stage: "platform",
      detail: "case excludes " + @testkit.host_platform(),
      evidence: None,
    }
  }
  try {
    guard fixture.comparison == Some("scenario") else {
      fail("only supported stateful scenarios have this pair executor")
    }
    guard @testkit.safe_relative_path(fixture.id) else {
      fail("unsafe scenario ID")
    }
    guard !@fs.exists(pair_root) else { fail("pair evidence already exists") }
    @fs.mkdir(pair_root, recursive=true)
    let native = execute_scenario(
      fixture,
      native_root,
      false,
      pair_root + "/native",
      retain_success=true,
    )
    let wasm = execute_scenario(
      fixture,
      wasm_root,
      true,
      pair_root + "/wasm",
      retain_success=true,
    )
    @fs.write_file(
      pair_root + "/native-report.json",
      @testkit.canonical_json(ToJson::to_json(native)),
    )
    @fs.write_file(
      pair_root + "/wasm-report.json",
      @testkit.canonical_json(ToJson::to_json(wasm)),
    )
    if native.result != "pass" || wasm.result != "pass" {
      return {
        ..base,
        result: if native.result == "infra" || wasm.result == "infra" {
          "infra"
        } else {
          "fail"
        },
        stage: "backend-contract",
        detail: "native=" +
        native.result +
        " " +
        native.detail +
        "; wasm=" +
        wasm.result +
        " " +
        wasm.detail,
        duration_ms: @async.now() - started,
      }
    }
    let native_snapshot = scenario_pair_snapshot(
      pair_root + "/native/" + fixture.id,
      fixture,
    )
    let wasm_snapshot = scenario_pair_snapshot(
      pair_root + "/wasm/" + fixture.id,
      fixture,
    )
    @fs.write_file(pair_root + "/native-observations.txt", native_snapshot)
    @fs.write_file(pair_root + "/wasm-observations.txt", wasm_snapshot)
    let equal = native_snapshot == wasm_snapshot
    {
      ..base,
      result: if equal {
        "pass"
      } else {
        "fail"
      },
      stage: if equal {
        "complete"
      } else {
        "backend-comparison"
      },
      detail: if equal {
        "Native and Wasm scenario traces, statuses and portable filesystem observations agree"
      } else {
        "scenario observations differ; inspect retained native/wasm observations and raw captures"
      },
      duration_ms: @async.now() - started,
      observations: ["status", "stdout", "stderr", "file-content"],
      missing_observations: [],
    }
  } catch {
    error =>
      {
        ..base,
        detail: error.to_string(),
        duration_ms: @async.now() - started,
      }
  }
}
