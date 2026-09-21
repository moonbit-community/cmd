///|
/// Legacy multi-command scenarios retain their original assertions. Register
/// their scope explicitly so filtering never silently executes the whole suite.
fn cohort_cases() -> Array[@testkit.Case] raise {
  let all = @cli.command_catalog().map(item => item.name)
  let specs : Array[(String, String, Array[String])] = [
    ("compat-catalog", "compat", all),
    ("compat-environment", "compat", ["sh", "make", "xargs", "env"]),
    ("compat-chunks", "compat", ["base64", "xxd", "tr"]),
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
    (
      "gnu-host",
      "gnu",
      ["base64", "cat", "cut", "head", "sha256sum", "sort", "tail", "tr"],
    ),
    (
      "stress-streams",
      "stress",
      [
        "cat", "head", "tail", "tee", "base64", "xxd", "wc", "tr", "sort", "uniq",
      ],
    ),
    ("policy-host", "policy", all),
  ]
  specs.map(spec => {
    let (id, suite, commands) = spec
    let fixture : @testkit.Case = @json.from_json({
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
      source_version: Some("workspace 0.2.0 retained cohort"),
      host_platforms: if suite == "gnu" {
        Some(["linux"])
      } else {
        None
      },
    }
  })
}

///|
fn case_in_suites(fixture : @testkit.Case, suites : Array[String]) -> Bool {
  let kind = fixture.comparison.unwrap_or("differential")
  suites.any(suite => {
    match suite {
      "contract" => kind == "contract" || fixture.expected_rejection is Some(_)
      "oracle" =>
        kind == "differential" ||
        kind == "exact" ||
        kind == "normalized" ||
        fixture.oracle == Some(true) ||
        kind == "oracle-scenario" ||
        fixture.expected_rejection is Some(_)
      "scenarios" => kind == "scenario"
      _ => kind == suite
    }
  })
}

///|
async fn execute_cohort(
  fixture : @testkit.Case,
  bin_root : String,
  backend : String,
  project_root : String,
  wasm_root : String,
) -> @testkit.CaseReport {
  let start = @async.now()
  let kind = fixture.comparison.unwrap()
  let level = if kind == "policy" {
    "boundary"
  } else if kind == "gnu" {
    "differential"
  } else {
    "contract"
  }
  let base : @testkit.CaseReport = {
    id: fixture.id,
    command: fixture.command,
    result: "pass",
    verification: level,
    stage: "assertion",
    detail: "",
    platform: @testkit.host_platform(),
    backend: if kind == "policy" {
      "wasm"
    } else {
      backend
    },
    source_version: fixture.source_version.unwrap(),
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
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
  if backend == "wasm" && kind != "policy" {
    return {
      ..base,
      result: "skip",
      stage: "backend",
      detail: "retained cohort uses Native; portable contracts and scenarios cover Wasm",
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
      "gnu-host" => run_gnu_differential(bin_root, failures)
      "stress-streams" => run_stress_cases(bin_root, failures)
      "policy-host" =>
        run_policy_suite(project_root, @fs.realpath(wasm_root), failures)
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
      ["retained-cohort-assertions"]
    } else {
      []
    },
  }
}
