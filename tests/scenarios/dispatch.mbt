///|
pub async fn execute_scenario(
  fixture : @harness.Case,
  root : String,
  report_dir : String,
  oracle_image? : String,
  retain_success~ : Bool = false,
  proof_catalog? : Json,
  proof_receipts? : Array[Json],
) -> @harness.CaseReport {
  let start = @async.now()
  let report_id = "scenario:" + fixture.id
  let device_boundary = fixture.id == "diff-directory-devices-boundary"
  let tee_boundary = fixture.id == "tee-default-pipe-boundary"
  let verification = if device_boundary ||
    tee_boundary ||
    fixture.id == "mv-windows-wasm-links-boundary" {
    "boundary"
  } else if oracle_image is Some(_) {
    "differential"
  } else {
    "contract"
  }
  if !fixture.platform_applies() {
    let report = @harness.suite_report(report_id, "wasm", start, [])
    return {
      ..report,
      command: fixture.command,
      result: "skip",
      verification,
      stage: "platform",
      detail: "case applies only to: " +
      fixture.host_platforms.unwrap_or([]).join(", "),
      observations: [],
    }
  }
  guard @harness.safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let evidence = report_dir + "/" + fixture.id
  if @fs.exists(evidence) {
    fail("evidence already exists; use a fresh report directory")
  }
  let work = evidence + "/work"
  @fs.mkdir(work, recursive=true)
  let failures : Array[String] = []
  let proof = match proof_catalog {
    Some(catalog) =>
      @harness.scenario_definition(catalog, fixture.id).map(definition => {
        @harness.ScenarioProof::new(fixture.id, definition)
      })
    None => None
  }
  let completed = @async.with_timeout_opt(
    fixture.timeout_ms.unwrap_or(
      if oracle_image is Some(_) {
        120000
      } else {
        15000
      },
    ),
    () => {
      match fixture.id {
        "tee-output-errors" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-output-errors-oracle" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-default-pipe-boundary" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "sh-interactive-session" =>
          shell_interactive_scenario(root, work, proof?)
        "make-ready-ack" => make_concurrency_scenario(root, work, proof?)
        "filesystem-fidelity" =>
          filesystem_fidelity_scenario(root, work, proof?)
        "mktemp-option-effects" =>
          mktemp_options_scenario(root, work, true, oracle_image?, proof?)
        "mktemp-option-effects-oracle" =>
          mktemp_options_scenario(root, work, true, oracle_image?)
        "mktemp-option-effects-windows" =>
          mktemp_options_scenario(root, work, false, oracle_image?, proof?)
        "diff-directory-devices-boundary" =>
          diff_directory_devices_boundary_scenario(root, work)
        "process-lifecycle" => process_lifecycle_scenario(root, work)
        "network-auth-cookie" => network_cli_scenario(root, work, proof?)
        "network-auth-cookie-oracle" =>
          network_cli_scenario(root, work, oracle_image?)
        "network-transfer-boundaries" =>
          network_transfer_scenario(root, work, proof?)
        "network-transfer-boundaries-oracle" =>
          network_transfer_scenario(root, work, oracle_image?)
        "mv-windows-wasm-links-boundary" =>
          windows_mv_links_scenario(root, work)
        _ => fail("unknown scenario: " + fixture.id)
      }
    },
  ) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("scenario deadline expired")
  }
  if proof is Some(proof) {
    failures.append(proof.errors())
    if proof_receipts is Some(receipts) {
      receipts.push(proof.receipt())
    }
  }
  let report = @harness.suite_report(report_id, "wasm", start, failures)
  let mut cleanup_error = false
  if failures.is_empty() && !retain_success {
    @async.protect_from_cancel(() => @fs.rmdir(evidence, recursive=true)) catch {
      error => {
        cleanup_error = true
        failures.push(error.to_string())
      }
    }
  }
  let infrastructure = cleanup_error ||
    failures.any(error => {
      error.contains("infrastructure") ||
      error.contains("no such file") ||
      error.contains("No such file")
    })
  {
    ..report,
    command: fixture.command,
    result: if infrastructure {
      "infra"
    } else {
      report.result
    },
    verification,
    observations: if fixture.id.has_prefix("tee-") && failures.is_empty() {
      ["status", "stderr", "file-content", "file-type"]
    } else if fixture.id.has_prefix("mktemp-option-effects") &&
      failures.is_empty() {
      if fixture.id == "mktemp-option-effects-windows" {
        ["status", "stdout", "stderr", "file-content", "file-type"]
      } else {
        ["status", "stdout", "stderr", "file-content", "file-type", "file-mode"]
      }
    } else if device_boundary && failures.is_empty() {
      ["status", "stdout", "stderr", "file-type", "symlink-target"]
    } else if device_boundary {
      []
    } else if windows_mv_scenario(fixture.id) && failures.is_empty() {
      [
        "status", "stdout", "stderr", "file-content", "file-type", "symlink-target",
      ]
    } else if windows_mv_scenario(fixture.id) {
      []
    } else {
      report.observations
    },
    source_version: fixture.source_version.unwrap_or("workspace"),
    detail: failures.join("; "),
    stage: if cleanup_error {
      "cleanup"
    } else if completed is None {
      "timeout"
    } else if infrastructure {
      "infrastructure"
    } else if failures.is_empty() {
      "complete"
    } else {
      "assertion"
    },
    evidence: if failures.is_empty() && !retain_success {
      None
    } else {
      Some(evidence)
    },
  }
}
