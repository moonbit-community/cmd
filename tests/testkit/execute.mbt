///|
pub async fn execute_contract(
  fixture : Case,
  root : String,
  wasm : Bool,
  report_dir : String,
  http_base? : String,
  retain_success~ : Bool = false,
  observer? : String,
) -> CaseReport {
  let start = @async.now()
  let verification = if fixture.expected_rejection is Some(_) {
    "boundary"
  } else {
    "contract"
  }
  ignore(wasm)
  let backend = if observer is Some(_) { "observer" } else { "wasm" }
  let base : CaseReport = {
    id: fixture.id,
    command: fixture.command,
    result: "skip",
    verification,
    stage: "platform",
    detail: "case excludes " + host_platform(),
    platform: host_platform(),
    backend,
    source_version: fixture.source_version.unwrap_or("workspace"),
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    local_contract: None,
    evidence: None,
  }
  let invalid = contract_errors(fixture)
  if !invalid.is_empty() {
    return {
      ..base,
      result: "infra",
      stage: "contract-validation",
      detail: invalid.join("; "),
    }
  }
  if !fixture.platform_applies() {
    return base
  }
  guard safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let work = report_dir + "/" + case_directory_name(fixture.id)
  if @fs.exists(work) {
    fail("evidence already exists: \{work}; choose a fresh --report-dir")
  }
  @fs.mkdir(work, recursive=true)
  let fixture_root = work + "/work"
  @fs.mkdir(fixture_root)
  let mut stage = "fixture"
  let errors : Array[String] = []
  let mut outcome = "pass"
  let mut result : RunResult? = None
  let mut evidence_path = work
  let dimensions = contract_observations(fixture)
  try {
    prepare_fixture(fixture_root, fixture, http_base?)
    let fixture = resolve_runtime_contract(fixture, fixture_root, http_base?)
    let before = if fixture.expected_rejection is Some(_) ||
      fixture.expected_files
      .unwrap_or([])
      .any(file => file.unchanged == Some(true)) {
      snapshot(
        fixture_root,
        observe=dimensions,
        baseline=true,
        preserve_identity=true,
      )
    } else {
      []
    }
    stage = "candidate"
    let args = expand_args(fixture.args, fixture_root, http_base?)
    let completed = run_with_deadline(
      observer.unwrap_or(command_program()),
      if observer is Some(_) {
        args
      } else {
        command_args(root, fixture.command, args)
      },
      fixture.timeout_ms.unwrap_or(15000),
      stdin=fixture.input(root=fixture_root, http_base?),
      cwd=fixture.working_directory(fixture_root),
      extra_env=controlled_environment(
        expand_environment(fixture.environment, fixture_root, http_base?),
      ),
    )
    let observed = completed.output
    result = Some(observed)
    if completed.cleanup_error is Some(error) {
      outcome = "infra"
      stage = "cleanup"
      errors.push(error)
    } else if completed.timed_out {
      outcome = "fail"
      stage = "timeout"
      errors.push("runner deadline expired; captured streams are partial")
    } else {
      stage = "assertion"
      match fixture.expected_rejection {
        Some(reason) => {
          let after = snapshot(
            fixture_root,
            observe=dimensions,
            preserve_identity=true,
          )
          if observed.status == 0 || !contains_bytes(observed.stderr, reason) {
            errors.push("expected rejection: " + reason)
          }
          if fixture.expected_status != 0 &&
            observed.status != fixture.expected_status {
            errors.push("rejection status differs from contract")
          }
          if fixture.expected_status != 0 {
            errors.append(
              check_contract(fixture, observed, fixture_root, http_base?),
            )
            errors.append(
              check_expected_files(
                fixture,
                fixture_root,
                http_base?,
                baseline=before,
              ),
            )
          }
          if observed.stdout != b"" {
            errors.push("unsupported operation wrote stdout")
          }
          if !snapshots_equal(before, after) {
            errors.push("rejected operation changed fixture")
          }
        }
        None => {
          errors.append(
            check_contract(fixture, observed, fixture_root, http_base?),
          )
          errors.append(
            check_expected_files(
              fixture,
              fixture_root,
              http_base?,
              baseline=before,
            ),
          )
          errors.append(check_runtime_contract(fixture, observed))
        }
      }
    }
  } catch {
    error => {
      outcome = "infra"
      errors.push(error.to_string())
    }
  }
  if outcome == "pass" && !errors.is_empty() {
    outcome = "fail"
  }
  if outcome != "pass" {
    if result is Some(observed) {
      @fs.write_file(work + "/stdout.bin", observed.stdout)
      @fs.write_file(work + "/stderr.bin", observed.stderr)
    }
  } else if retain_success {
    stage = "snapshot"
    try {
      if result is Some(observed) {
        @fs.write_file(work + "/stdout.bin", observed.stdout)
        @fs.write_file(work + "/stderr.bin", observed.stderr)
        @fs.write_file(work + "/status.txt", observed.status.to_string())
        @fs.write_file(
          work + "/snapshot.txt",
          snapshot_fingerprint(
            snapshot(
              fixture_root,
              observe=dimensions,
              content=dimensions.contains("content") ||
                fixture.expected_rejection is Some(_) ||
                fixture.expected_files
                .unwrap_or([])
                .any(file => file.unchanged == Some(true)),
            ),
          ),
        )
      }
    } catch {
      error => {
        outcome = "infra"
        errors.push(error.to_string())
      }
    }
  } else {
    stage = "cleanup"
    @async.protect_from_cancel(() => @fs.rmdir(work, recursive=true)) catch {
      error => {
        outcome = "infra"
        errors.push(error.to_string())
        // The fixture may itself have removed write access from `work`.
        // Preserve the completed candidate result in a sibling directory so
        // cleanup failure cannot erase the only stream/status evidence.
        if result is Some(observed) {
          let fallback = report_dir +
            "/" +
            case_directory_name(fixture.id) +
            ".cleanup-evidence"
          try {
            @fs.mkdir(fallback)
            @fs.write_file(fallback + "/stdout.bin", observed.stdout)
            @fs.write_file(fallback + "/stderr.bin", observed.stderr)
            @fs.write_file(
              fallback + "/status.txt",
              observed.status.to_string(),
            )
            @fs.write_file(fallback + "/fixture-path.txt", work + "\n")
            evidence_path = fallback
          } catch {
            write_error =>
              errors.push(
                "cleanup evidence write failed: " + write_error.to_string(),
              )
          }
        }
      }
    }
  }
  {
    ..base,
    result: outcome,
    stage: if outcome == "pass" {
      "complete"
    } else {
      stage
    },
    detail: errors.join("; "),
    duration_ms: @async.now() - start,
    observations: if outcome == "pass" {
      ["status", "stdout", "stderr", ..dimensions]
    } else {
      []
    },
    evidence: if outcome == "pass" && !retain_success {
      None
    } else {
      Some(evidence_path)
    },
  }
}
