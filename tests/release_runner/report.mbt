///|
priv struct CaseReport {
  id : String
  command : String
  version : String
  mut category : String
  mut detail : String
}

///|
fn result_class(category : String) -> String {
  match category {
    "passed" | "availability_passed" | "boundary_passed" => "pass"
    "skipped_platform" => "skip"
    "asset_unavailable"
    | "registry_transport"
    | "oracle_failure"
    | "runner_infra"
    | "invalid_contract"
    | "cleanup_failure" => "infra"
    _ => "fail"
  }
}

///|
fn report_verification(
  report : CaseReport,
  fixtures : Array[ReleaseCase],
  differential : Bool,
) -> String {
  for fixture in fixtures {
    if fixture.id == report.id {
      return verification_level(fixture, differential)
    }
  }
  "availability"
}

///|
fn shared_report(
  report : CaseReport,
  fixtures : Array[ReleaseCase],
  differential : Bool,
  timings : Map[String, Int64],
) -> @testkit.CaseReport {
  let observations : Array[String] = []
  for fixture in fixtures {
    if fixture.id == report.id && result_class(report.category) == "pass" {
      match report_verification(report, fixtures, differential) {
        "availability" => observations.push("status")
        "contract" => {
          observations.append(@testkit.contract_observations(fixture))
          observations.push("status")
          if fixture.expected_stdout_hex is Some(_) ||
            fixture.expected_stdout_text is Some(_) {
            observations.push("stdout-bytes")
          }
          if fixture.expected_stderr_hex is Some(_) ||
            fixture.expected_stderr_text is Some(_) {
            observations.push("stderr-bytes")
          }
          if fixture.expected_stdout_contains is Some(_) ||
            !fixture.expected_stdout_contains_all.unwrap_or([]).is_empty() ||
            fixture.expected_stdout_ends_with_newline is Some(_) {
            observations.push("stdout-contract")
          }
          if fixture.expected_stderr_contains is Some(_) ||
            !fixture.expected_stderr_contains_all.unwrap_or([]).is_empty() ||
            fixture.expected_stderr_ends_with_newline is Some(_) ||
            fixture.forbidden_stderr is Some(_) {
            observations.push("stderr-contract")
          }
        }
        "boundary" => {
          observations.append([
            "nonzero-status", "diagnostic", "content", "type",
          ])
          observations.append(@testkit.contract_observations(fixture))
        }
        _ => {
          observations.append([
            "status", "stdout-bytes", "stderr-bytes", "content", "type",
          ])
          observations.append(fixture.observe.unwrap_or([]))
        }
      }
    }
  }
  let detail_parts = report.detail.split("; artifacts: ").collect()
  let evidence = if detail_parts.length() > 1 {
    Some(
      detail_parts[detail_parts.length() - 1]
      .split("; cause:")
      .next()
      .unwrap()
      .to_owned(),
    )
  } else {
    None
  }
  {
    id: report.id,
    command: report.command,
    result: result_class(report.category),
    verification: report_verification(report, fixtures, differential),
    stage: report.category,
    detail: report.detail,
    backend: "published-wasm",
    platform: @testkit.host_platform(),
    source_version: "cli/" + report.command + "@" + report.version,
    duration_ms: timings.get(report.id).unwrap_or(0L),
    observations,
    missing_observations: if report.category == "timeout" ||
      report.detail.contains("oracle did not finish before timeout") {
      ["complete stdout", "complete stderr"]
    } else if report.category == "runner_infra" &&
      report.detail.contains("observation") {
      ["required filesystem observations"]
    } else {
      []
    },
    evidence,
  }
}

///|
async fn write_report(
  directory : String,
  reports : Array[CaseReport],
  fixtures : Array[ReleaseCase],
  differential : Bool,
  timings : Map[String, Int64],
) -> Unit {
  let shared = reports.map(report => {
    shared_report(report, fixtures, differential, timings)
  })
  @testkit.write_reports(directory, shared)
  let coverage = fixtures.map(fixture => {
    let semantic = shared.any(report => {
      report.id == fixture.id && report.semantic_pass()
    })
    let record : Map[String, Json] = {
      "id": fixture.id.to_json(),
      "command": fixture.command.to_json(),
      "selected": true.to_json(),
      "platform_applies": case_supported_on_host(fixture, host_platform()).to_json(),
      "executed": reports
      .any(report => {
        report.id == fixture.id && result_class(report.category) != "skip"
      })
      .to_json(),
      "options_declared": fixture.coverage.unwrap_or([]).to_json(),
      "options_verified": (if semantic {
        fixture.coverage.unwrap_or([])
      } else {
        []
      }).to_json(),
    }
    record.to_json().stringify()
  })
  @fs.write_file(directory + "/coverage.jsonl", coverage.join("\n") + "\n")
}
