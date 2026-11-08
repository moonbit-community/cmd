///|
/// Multi-command scenarios preserve their original assertions. Register
/// their scope explicitly so filtering never silently executes the whole suite.
pub fn cohort_cases() -> Array[@harness.Case] raise {
  let all = @catalog.commands().map(item => item.name)
  let specs : Array[(String, String, Array[String])] = [
    ("compat-catalog", "compat", all),
    ("compat-environment", "compat", ["sh", "make", "xargs", "env", "printenv"]),
    ("compat-chunks", "compat", ["base64", "xxd"]),
    (
      "compat-process-composition",
      "compat",
      ["find", "xargs", "env", "printf", "false", "printenv", "pwd"],
    ),
    ("compat-sleep-cancellation", "compat", ["sleep"]),
    ("compat-tail-follow", "compat", ["tail"]),
    ("compat-http", "compat", ["curl", "wget"]),
    ("compat-https", "compat", ["curl", "wget"]),
    ("compat-proxy", "compat", ["curl", "wget"]),
    ("stress-streams", "stress", ["seq", "wc"]),
    ("policy-host", "policy", all),
  ]
  specs.map(spec => {
    let (id, suite, commands) = spec
    let fixture : @harness.Case = @json.from_json({
      "id": id,
      "command": commands[0],
      "args": [],
      "files": [],
      "environment": {},
      "expected_status": 0,
      "normalizations": [],
    })
    {
      ..fixture,
      related_commands: Some(commands),
      comparison: Some(suite),
      source_version: Some("workspace cohort"),
      host_platforms: None,
    }
  })
}

///|
pub async fn execute_cohort(
  fixture : @harness.Case,
  bin_root : String,
  backend : String,
  project_root : String,
  wasm_root : String,
) -> @harness.CaseReport {
  let start = @async.now()
  let kind = fixture.comparison.unwrap()
  let level = if kind == "policy" { "boundary" } else { "contract" }
  let report_id = if kind == "policy" {
    "policy:" + fixture.id
  } else {
    "cohort:" + fixture.id
  }
  let base : @harness.CaseReport = {
    id: report_id,
    command: fixture.command,
    result: "pass",
    verification: level,
    stage: "assertion",
    detail: "",
    platform: @harness.host_platform(),
    backend: if kind == "policy" {
      "wasm"
    } else {
      backend
    },
    source_version: fixture.source_version.unwrap(),
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    local_contract: None,
    evidence: None,
  }
  if !fixture.platform_applies() {
    return {
      ..base,
      result: "skip",
      stage: "platform",
      detail: "cohort requires GNU/Linux",
    }
  }
  let failures : Array[String] = []
  let mut infrastructure = false
  try {
    match fixture.id {
      "compat-catalog" => check_catalog(bin_root, true, failures)
      "compat-environment" => run_environment_boundary_cases(bin_root, failures)
      "compat-chunks" => run_chunk_boundary_cases(bin_root, failures)
      "compat-process-composition" =>
        run_text_process_composition_cases(bin_root, failures)
      "compat-sleep-cancellation" => run_sleep_cancel_case(bin_root, failures)
      "compat-tail-follow" => run_tail_follow_cases(bin_root, failures)
      "compat-http" => run_http_cases(bin_root, failures)
      "compat-https" => run_https_cases(bin_root, failures)
      "compat-proxy" => run_proxy_cases(bin_root, failures)
      "stress-streams" => run_stress_cases(bin_root, failures)
      "policy-host" => run_policy_suite(project_root, wasm_root, failures)
      _ => fail("unregistered cohort")
    }
  } catch {
    error => {
      infrastructure = true
      failures.push(error.to_string())
    }
  }
  {
    ..base,
    result: if infrastructure {
      "infra"
    } else if failures.is_empty() {
      "pass"
    } else {
      "fail"
    },
    stage: if infrastructure {
      "infrastructure"
    } else if failures.is_empty() {
      "complete"
    } else {
      "assertion"
    },
    detail: failures.join("; "),
    duration_ms: @async.now() - start,
    observations: if failures.is_empty() {
      ["status", "stdout", "stderr"]
    } else {
      []
    },
  }
}
