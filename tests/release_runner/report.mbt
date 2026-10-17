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
fn oracle_preflight_report(detail : String) -> CaseReport {
  {
    id: "oracle-preflight",
    command: "runner",
    version: "",
    category: "oracle_failure",
    detail,
  }
}

///|
fn release_oracle_profile_id(
  reports : Array[CaseReport],
  oracle_image_digest : String,
) -> String {
  if oracle_image_digest != "" ||
    reports.any(report => report.id == "oracle-preflight") {
    "pinned-oracle-v1"
  } else {
    ""
  }
}

///|
/// Retain a machine-readable infrastructure result even when no case started.
/// The run metadata stays partial because the oracle identity was not proved.
async fn write_oracle_preflight_failure(
  directory : String?,
  fixtures : Array[ReleaseCase],
  manifest_path : String,
  case_corpus_path : String,
  started_at_ms : Int64,
  detail : String,
  oracle_profile_id? : String,
  registry_path~ : String = "tests/registry/registry.json",
) -> Unit {
  match directory {
    Some(path) => {
      if !@fs.exists(path) {
        @fs.mkdir(path, recursive=true)
      }
      write_report(
        path,
        [oracle_preflight_report(detail)],
        fixtures,
        true,
        Map([]),
        manifest_path,
        case_corpus_path,
        started_at_ms,
        "",
        "",
        oracle_profile_id?,
        registry_path~,
      )
    }
    None => ()
  }
}

///|
async fn write_release_preflight_failure(
  directory : String?,
  manifest_path : String,
  case_corpus_path : String,
  registry_path : String,
  started_at_ms : Int64,
  detail : String,
) -> Unit {
  if directory is Some(directory) {
    write_report(
      directory,
      [
        {
          id: "release:validation-infrastructure",
          command: "runner",
          version: "",
          category: "runner_infra",
          detail,
        },
      ],
      [],
      false,
      Map([]),
      manifest_path,
      case_corpus_path,
      started_at_ms,
      "",
      "",
      registry_path~,
    )
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
            "nonzero-status", "diagnostic", "stderr", "content", "type",
          ])
          observations.append(@testkit.contract_observations(fixture))
        }
        _ => {
          observations.append(["status", "stdout-bytes", "content", "type"])
          observations.push(
            if fixture.expected_stderr_contains is Some(_) &&
              fixture.diagnostic_reason is Some(_) {
              "stderr-contract"
            } else {
              "stderr-bytes"
            },
          )
          observations.append(@testkit.contract_observations(fixture))
        }
      }
    }
  }
  // Coverage uses canonical stream dimensions; detailed forms retain whether
  // the assertion compared complete bytes or a documented contract.
  if observations.contains("stdout-bytes") ||
    observations.contains("stdout-contract") {
    observations.push("stdout")
  }
  if observations.contains("stderr-bytes") ||
    observations.contains("stderr-contract") {
    observations.push("stderr")
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
  manifest_path : String,
  case_corpus_path : String,
  started_at_ms : Int64,
  oracle_image_digest : String,
  oracle_versions_hash : String,
  oracle_profile_id? : String,
  registry_path~ : String = "tests/registry/registry.json",
  start_metadata? : @testkit.RunMetadata,
) -> Unit {
  let shared = reports.map(report => {
    shared_report(report, fixtures, differential, timings)
  })
  let coordinates = reports
    .filter(report => result_class(report.category) != "skip")
    .map(report => "cli/" + report.command + "@" + report.version)
    .filter(value => !value.has_suffix("@"))
  coordinates.sort()
  let metadata = @testkit.collect_run_metadata(
    "release-" + @async.now().to_string(),
    manifest_path~,
    case_corpus_path~,
    registry_path~,
    oracle_profile_id=oracle_profile_id.unwrap_or(
      release_oracle_profile_id(reports, oracle_image_digest),
    ),
    oracle_image_digest~,
    moonx_coordinates=coordinates,
    started_at_ms~,
    ended_at_ms=@async.now(),
  )
  let metadata = @testkit.with_oracle_versions_hash(
    metadata, oracle_versions_hash,
  )
  let metadata = @testkit.with_wasm_artifact_hash(
    metadata,
    @testkit.moonx_artifact_digest(coordinates),
  )
  let metadata = match start_metadata {
    Some(start) => @testkit.finalize_run_metadata(start, metadata)
    None => metadata
  }
  @testkit.write_reports_with_metadata(directory, shared, metadata)
  let coverage = fixtures.map(fixture => {
    let semantic = shared.any(report => {
      report.id == fixture.id && report.semantic_pass()
    })
    let record : Json = {
      "id": Json(fixture.id),
      "command": Json(fixture.command),
      "run_id": Json(metadata.run_id),
      "registry_revision": Json(metadata.registry_hash),
      "artifact_id": Json(@testkit.artifact_id(metadata)),
      "oracle_profile_id": Json(metadata.oracle_profile_id),
      "reproducibility_status": Json(metadata.reproducibility_status),
      "selected": Json(true),
      "platform_applies": Json(case_supported_on_host(fixture, host_platform())),
      "executed": Json(
        reports.any(report => {
          report.id == fixture.id && result_class(report.category) != "skip"
        }),
      ),
      "options_declared": Json(fixture.coverage.unwrap_or([])),
      "options_verified": Json(
        if semantic {
          fixture.coverage.unwrap_or([])
        } else {
          []
        },
      ),
    }
    record.stringify()
  })
  @fs.write_file(directory + "/coverage.jsonl", coverage.join("\n") + "\n")
}
