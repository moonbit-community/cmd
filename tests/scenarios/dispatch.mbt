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
        "typst-artifacts" => typst_artifacts_scenario(root, work, proof?)
        "typst-watch" => typst_watch_scenario(root, work, proof?)
        "tee-output-errors" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-output-errors-oracle" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-default-pipe-boundary" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "sh-interactive-session" =>
          shell_interactive_scenario(root, work, proof?)
        "f31-sh-language-session" =>
          shell_language_session_scenario(root, work, proof?)
        "f31-sh-merged-child" => shell_merged_child_scenario(root, work, proof?)
        "f31-sh-test-size-platform" =>
          shell_size_platform_scenario(
            root,
            work,
            report_dir + "/" + fixture.id + ".observations.json",
            proof?,
          )
        "f31-sh-test-size-posix" =>
          shell_size_posix_scenario(root, work, proof?)
        "f31-sh-printf-state" => printf_state_scenario(root, work, proof?)
        "f31-sh-printf-state-oracle" => {
          guard oracle_image is Some(image) else {
            fail("printf state oracle requires a sealed oracle")
          }
          printf_state_scenario(root, work, oracle_image=image)
        }
        "f31-make-recursive-language" =>
          make_recursive_language_scenario(root, work, proof?)
        "f31-make-fifo" => make_fifo_scenario(root, work, proof?)
        "f31-make-gnu-jobserver" => {
          guard oracle_image is Some(image) else {
            fail("GNU jobserver scenario requires a sealed oracle")
          }
          make_gnu_jobserver_scenario(root, work, image)
        }
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
        "yes-stream-lifecycle" =>
          yes_stream_lifecycle_scenario(root, work, proof?)
        "compression-selectors" =>
          compression_selectors_scenario(root, work, proof?)
        "metadata-relations" =>
          metadata_scenario(
            root,
            work,
            report_dir + "/metadata-relations.observations.json",
            proof?,
          )
        "f29-mkdir-umasks" =>
          mkdir_umask_scenario(
            root,
            work,
            report_dir + "/f29-mkdir-umasks.observations.json",
            proof?,
          )
        "f29-sparse-size" =>
          filesystem_sparse_scenario(
            root,
            work,
            report_dir + "/f29-sparse-size.observations.json",
            proof?,
          )
        "f29-sparse-size-oracle" => {
          guard oracle_image is Some(image) else {
            fail("sparse oracle requires a sealed oracle")
          }
          filesystem_sparse_scenario(
            root,
            work,
            report_dir + "/f29-sparse-size-oracle.observations.json",
            oracle_image=image,
          )
        }
        "f29-find-size-unreadable" | "f29-test-size-unreadable" =>
          filesystem_unreadable_scenario(
            root,
            work,
            report_dir + "/" + fixture.id + ".observations.json",
            fixture.command,
            proof?,
          )
        "f29-find-size-unreadable-oracle" | "f29-test-size-unreadable-oracle" => {
          guard oracle_image is Some(image) else {
            fail("unreadable size oracle requires a sealed oracle")
          }
          filesystem_unreadable_scenario(
            root,
            work,
            report_dir + "/" + fixture.id + ".observations.json",
            fixture.command,
            oracle_image=image,
          )
        }
        "f29-special-kinds" =>
          filesystem_special_scenario(
            root,
            work,
            report_dir + "/f29-special-kinds.observations.json",
            proof?,
          )
        "f29-windows-metadata" =>
          filesystem_windows_scenario(
            root,
            work,
            report_dir + "/f29-windows-metadata.observations.json",
            proof?,
          )
        "f29-subsecond-order" =>
          filesystem_precision_scenario(
            root,
            work,
            report_dir + "/f29-subsecond-order.observations.json",
            proof?,
          )
        "f29-subsecond-order-oracle" => {
          guard oracle_image is Some(image) else {
            fail("subsecond oracle requires a sealed oracle")
          }
          filesystem_precision_scenario(
            root,
            work,
            report_dir + "/f29-subsecond-order-oracle.observations.json",
            oracle_image=image,
          )
        }
        "f29-directory-size" =>
          filesystem_directory_size_scenario(
            root,
            work,
            report_dir + "/f29-directory-size.observations.json",
            proof?,
          )
        "f29-time-references" =>
          filesystem_time_scenario(
            root,
            work,
            report_dir + "/f29-time-references.observations.json",
            proof?,
          )
        "f29-time-references-oracle" => {
          guard oracle_image is Some(image) else {
            fail("time oracle requires a sealed oracle")
          }
          filesystem_time_scenario(
            root,
            work,
            report_dir + "/f29-time-references-oracle.observations.json",
            oracle_image=image,
          )
        }
        "f29-predicate-errors" =>
          filesystem_error_scenario(
            root,
            work,
            report_dir + "/f29-predicate-errors.observations.json",
            proof?,
          )
        "f29-predicate-errors-oracle" => {
          guard oracle_image is Some(image) else {
            fail("error oracle requires a sealed oracle")
          }
          filesystem_error_scenario(
            root,
            work,
            report_dir + "/f29-predicate-errors-oracle.observations.json",
            oracle_image=image,
          )
        }
        "f29-special-kinds-oracle" => {
          guard oracle_image is Some(image) else {
            fail("special kind oracle requires a sealed oracle")
          }
          filesystem_special_scenario(
            root,
            work,
            report_dir + "/f29-special-kinds-oracle.observations.json",
            oracle_image=image,
          )
        }
        "f29-mkdir-umasks-oracle" => {
          guard oracle_image is Some(image) else {
            fail("umask oracle requires a sealed oracle")
          }
          @fs.mkdir(work + "/candidate")
          @fs.mkdir(work + "/oracle")
          mkdir_umask_scenario(
            root,
            work + "/candidate",
            report_dir + "/f29-mkdir-umasks-oracle.candidate.json",
          )
          mkdir_umask_scenario(
            root,
            work + "/oracle",
            report_dir + "/f29-mkdir-umasks-oracle.gnu.json",
            oracle_image=image,
          )
        }
        "f29-metadata-selectors-oracle" => {
          guard oracle_image is Some(image) else {
            fail("metadata selectors require a sealed oracle")
          }
          metadata_scenario(
            root,
            work,
            report_dir + "/f29-metadata-selectors-oracle.observations.json",
            selectors_only=true,
            oracle_image=image,
          )
        }
        "rg-type-listing" => type_listing_scenario(root, work, proof?)
        "sort-live-spill" => sort_spill_scenario(root, work, proof?)
        "rm-root-guard" => removal_guard_scenario(root, work, proof?)
        "xargs-verbose-argv" => xargs_verbose_scenario(root, work, proof?)
        "timeout-child-lifecycle" =>
          timeout_command_scenario(root, work, proof?)
        "csplit-fragment-retention" =>
          csplit_retention_scenario(root, work, proof?)
        "network-deadline-effects" =>
          network_deadlines_scenario(root, work, proof?)
        "network-retry-effects" => network_retries_scenario(root, work, proof?)
        "network-refusal-recovery" => refused_retry_scenario(root, work, proof?)
        "network-option-effects" => network_options_scenario(root, work, proof?)
        "tail-follow-interval" => follow_interval_scenario(root, work, proof?)
        "stream-failure-prefixes" => failure_prefix_scenario(root, work, proof?)
        "ls-link-facets" => link_dereference_scenario(root, work, proof?)
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
