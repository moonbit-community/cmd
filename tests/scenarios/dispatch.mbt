///|
pub async fn execute_scenario(
  fixture : @harness.Case,
  root : String,
  report_dir : String,
  oracle_image? : String,
  retain_success~ : Bool = false,
) -> @harness.CaseReport {
  let start = @async.now()
  // Network comparisons need the candidate and oracle wire/stream receipts
  // after success as well as failure; a suite-level pass is not that evidence.
  let retain_success = retain_success || @network.supports(fixture.id)
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
  // Background indexing can read new files and change atime without a command
  // invocation. Exclude the fixture before creating any files; retain every
  // timestamp assertion and the host filesystem's normal access-time behavior.
  let work = evidence +
    (if @async.platform is MacOS { "/work.noindex" } else { "/work" })
  @fs.mkdir(work, recursive=true)
  let failures : Array[String] = []
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
        "serve-static" => serve_static_scenario(root, work, false)
        "serve-policy" => serve_static_scenario(root, work, true)
        "typst-artifacts" => typst_artifacts_scenario(root, work)
        "typst-watch" => typst_watch_scenario(root, work)
        "tee-output-errors" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-output-errors-oracle" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "tee-default-pipe-boundary" =>
          tee_modes_scenario(root, work, tee_boundary, oracle_image?)
        "sh-interactive-session" => shell_interactive_scenario(root, work)
        "f31-sh-language-session" => shell_language_session_scenario(root, work)
        "f31-sh-merged-child" => shell_merged_child_scenario(root, work)
        "f31-sh-test-size-platform" =>
          shell_size_platform_scenario(
            root,
            work,
            report_dir + "/" + fixture.id + ".observations.json",
          )
        "f31-sh-test-size-posix" => shell_size_posix_scenario(root, work)
        "f31-sh-printf-state" =>
          printf_state_scenario(root, work, oracle_image?)
        "f31-sh-printf-state-oracle" => {
          guard oracle_image is Some(image) else {
            fail("printf state oracle requires a sealed oracle")
          }
          printf_state_scenario(root, work, oracle_image=image)
        }
        "f31-make-recursive-language" =>
          make_recursive_language_scenario(root, work)
        "f31-make-fifo" => make_fifo_scenario(root, work)
        "f31-make-gnu-jobserver" => {
          guard oracle_image is Some(image) else {
            fail("GNU jobserver scenario requires a sealed oracle")
          }
          make_gnu_jobserver_scenario(root, work, image)
        }
        "make-ready-ack" => make_concurrency_scenario(root, work)
        "filesystem-fidelity" => filesystem_fidelity_scenario(root, work)
        "mktemp-option-effects" =>
          mktemp_options_scenario(root, work, true, oracle_image?)
        "mktemp-option-effects-oracle" =>
          mktemp_options_scenario(root, work, true, oracle_image?)
        "mktemp-option-effects-windows" =>
          mktemp_options_scenario(root, work, false, oracle_image?)
        "diff-directory-devices-boundary" =>
          diff_directory_devices_boundary_scenario(root, work)
        "process-lifecycle" => process_lifecycle_scenario(root, work)
        "yes-stream-lifecycle" =>
          yes_stream_lifecycle_scenario(root, work, oracle_image?)
        "compression-selectors" => compression_selectors_scenario(root, work)
        "metadata-relations" =>
          metadata_scenario(
            root,
            work,
            report_dir + "/metadata-relations.observations.json",
            oracle_image?,
          )
        "f29-mkdir-umasks" =>
          mkdir_umask_event(root, work, report_dir, fixture.id, oracle_image?)
        "f29-sparse-size" =>
          filesystem_sparse_scenario(
            root,
            work,
            report_dir + "/f29-sparse-size.observations.json",
            oracle_image?,
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
            oracle_image?,
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
            oracle_image?,
          )
        "f29-windows-metadata" =>
          filesystem_windows_scenario(
            root,
            work,
            report_dir + "/f29-windows-metadata.observations.json",
          )
        "f29-subsecond-order" =>
          filesystem_precision_scenario(
            root,
            work,
            report_dir + "/f29-subsecond-order.observations.json",
            oracle_image?,
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
          )
        "f29-time-references" =>
          filesystem_time_scenario(
            root,
            work,
            report_dir + "/f29-time-references.observations.json",
            oracle_image?,
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
            oracle_image?,
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
          mkdir_umask_event(
            root,
            work,
            report_dir,
            fixture.id,
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
        "rg-type-listing" => type_listing_scenario(root, work)
        "sort-live-spill" => sort_spill_scenario(root, work)
        "rm-root-guard" => removal_guard_scenario(root, work)
        "xargs-verbose-argv" => xargs_verbose_scenario(root, work)
        "timeout-child-lifecycle" => timeout_command_scenario(root, work)
        "csplit-fragment-retention" => csplit_retention_scenario(root, work)
        "network-deadline-effects" => network_deadlines_scenario(root, work)
        "network-retry-effects" => network_retries_scenario(root, work)
        "network-refusal-recovery" => refused_retry_scenario(root, work)
        "network-option-effects" => network_options_scenario(root, work)
        "tail-follow-interval" => follow_interval_scenario(root, work)
        "stream-failure-prefixes" => failure_prefix_scenario(root, work)
        "ls-link-facets" => link_dereference_scenario(root, work)
        "network-auth-cookie" => network_cli_scenario(root, work, oracle_image?)
        "network-curl-http-cookie" =>
          @network.run(
            fixture.id,
            workspace_network_executor(root),
            work,
            oracle_image?,
          )
        "network-curl-http-cookie-oracle" =>
          @network.run(
            fixture.id,
            workspace_network_executor(root),
            work,
            oracle_image?,
          )
        "network-wget-http-cookie" =>
          @network.run(
            fixture.id,
            workspace_network_executor(root),
            work,
            oracle_image?,
          )
        "network-wget-http-cookie-oracle" =>
          @network.run(
            fixture.id,
            workspace_network_executor(root),
            work,
            oracle_image?,
          )
        "network-curl-cookie-lifecycle" =>
          network_curl_transfers_scenario(
            root,
            work,
            corpus="curl-cookie-lifecycle",
            oracle_image?,
          )
        "network-curl-cookie-lifecycle-oracle" =>
          network_curl_transfers_scenario(
            root,
            work,
            corpus="curl-cookie-lifecycle",
            oracle_image?,
          )
        "network-curl-http-retry" =>
          network_curl_transfers_scenario(
            root,
            work,
            corpus="curl-http-retry",
            oracle_image?,
          )
        "network-curl-http-retry-oracle" =>
          network_curl_transfers_scenario(
            root,
            work,
            corpus="curl-http-retry",
            oracle_image?,
          )
        "network-curl-cookie-domains" =>
          network_cookie_domains_scenario(
            root,
            work,
            tool="curl",
            oracle_image?,
          )
        "network-curl-cookie-domains-oracle" =>
          network_cookie_domains_scenario(
            root,
            work,
            tool="curl",
            oracle_image?,
          )
        "network-wget-cookie-domains" =>
          network_cookie_domains_scenario(
            root,
            work,
            tool="wget",
            oracle_image?,
          )
        "network-wget-cookie-domains-oracle" =>
          network_cookie_domains_scenario(
            root,
            work,
            tool="wget",
            oracle_image?,
          )
        "network-idna" => network_idna_scenario(root, work, oracle_image?)
        "network-wget-cookies" =>
          network_wget_cookies_scenario(root, work, oracle_image?)
        "network-wget-cookies-oracle" =>
          network_wget_cookies_scenario(root, work, oracle_image?)
        "network-wget-cookie-expiry" =>
          network_wget_cookies_scenario(
            root,
            work,
            corpus="wget-cookie-expiry",
            oracle_image?,
          )
        "network-wget-cookie-expiry-oracle" =>
          network_wget_cookies_scenario(
            root,
            work,
            oracle_image?,
            corpus="wget-cookie-expiry",
          )
        "network-wget-cookie-dates" =>
          network_wget_cookies_scenario(
            root,
            work,
            corpus="wget-cookie-dates",
            oracle_image?,
          )
        "network-wget-cookie-dates-oracle" =>
          network_wget_cookies_scenario(
            root,
            work,
            oracle_image?,
            corpus="wget-cookie-dates",
          )
        "network-wget-authentication" =>
          network_wget_authentication_scenario(root, work, oracle_image?)
        "network-wget-authentication-oracle" =>
          network_wget_authentication_scenario(root, work, oracle_image?)
        "network-wget-authentication-session"
        | "network-wget-authentication-replay"
        | "network-wget-authentication-rejection"
        | "network-wget-authentication-option-error" =>
          network_wget_authentication_scenario(root, work, id=fixture.id)
        "network-idna-oracle" =>
          network_idna_scenario(root, work, oracle_image?)
        "network-cookie-suffix" =>
          network_cookie_suffix_scenario(root, work, oracle_image?)
        "network-cookie-suffix-oracle" =>
          network_cookie_suffix_scenario(root, work, oracle_image?)
        "network-auth-cookie-oracle" =>
          network_cli_scenario(root, work, oracle_image?)
        "network-transfer-boundaries" =>
          network_transfer_scenario(root, work, oracle_image?)
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
  let report = @harness.suite_report(report_id, "wasm", start, failures)
  let mut cleanup_error = false
  let mut retained = Some(evidence)
  if failures.is_empty() {
    @async.protect_from_cancel(() => {
      if retain_success {
        retained = Some(@harness.compact_evidence(evidence))
      } else {
        @fs.rmdir(evidence, recursive=true)
        retained = None
      }
    }) catch {
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
    evidence: retained,
  }
}
