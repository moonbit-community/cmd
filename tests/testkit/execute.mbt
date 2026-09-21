///|
pub async fn execute_contract(
  fixture : Case,
  root : String,
  wasm : Bool,
  report_dir : String,
  http_base? : String,
) -> CaseReport {
  let start = @async.now()
  let verification = if fixture.expected_rejection is Some(_) {
    "boundary"
  } else {
    "contract"
  }
  let backend = if wasm { "wasm" } else { "native" }
  let base : CaseReport = {
    id: fixture.id,
    command: fixture.command,
    result: "skip",
    verification,
    stage: "platform",
    detail: "case excludes " + host_platform(),
    platform: host_platform(),
    backend,
    source_version: fixture.source_version.unwrap_or("workspace 0.2.0"),
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    evidence: None,
  }
  if !fixture.platform_applies() {
    return base
  }
  guard safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let invalid = contract_errors(fixture)
  if !invalid.is_empty() {
    return {
      ..base,
      result: "infra",
      stage: "contract-validation",
      detail: invalid.join("; "),
    }
  }
  let work = report_dir + "/" + fixture.id
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
  let dimensions = contract_observations(fixture)
  try {
    prepare_fixture(fixture_root, fixture, http_base?)
    let before = if fixture.expected_rejection is Some(_) {
      snapshot(fixture_root, observe=dimensions, baseline=true)
    } else {
      []
    }
    stage = "candidate"
    let args = expand_args(fixture.args, fixture_root, http_base?)
    let completed = run_with_deadline(
      if wasm {
        "moonrun"
      } else {
        executable_path(root, fixture.command)
      },
      if wasm {
        [wasm_path(root, fixture.command), "--", ..args]
      } else {
        args
      },
      fixture.timeout_ms.unwrap_or(15000),
      stdin=fixture.input(root=fixture_root, http_base?),
      cwd=fixture.working_directory(fixture_root),
      extra_env=controlled_environment(fixture.environment),
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
          if observed.status == 0 || !contains_bytes(observed.stderr, reason) {
            errors.push("expected rejection: " + reason)
          }
          if fixture.expected_status != 0 &&
            observed.status != fixture.expected_status {
            errors.push("rejection status differs from contract")
          }
          if fixture.expected_status != 0 {
            errors.append(check_contract(fixture, observed, fixture_root))
            errors.append(check_expected_files(fixture, fixture_root))
          }
          if observed.stdout != b"" {
            errors.push("unsupported operation wrote stdout")
          }
          if !snapshots_equal(
              before,
              snapshot(fixture_root, observe=dimensions),
            ) {
            errors.push("rejected operation changed fixture")
          }
        }
        None => {
          errors.append(check_contract(fixture, observed, fixture_root))
          errors.append(check_expected_files(fixture, fixture_root))
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
  } else {
    stage = "cleanup"
    @async.protect_from_cancel(() => @fs.rmdir(work, recursive=true)) catch {
      error => {
        outcome = "infra"
        errors.push(error.to_string())
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
    evidence: if outcome == "pass" {
      None
    } else {
      Some(work)
    },
  }
}
