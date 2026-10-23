///|
fn usage() -> String {
  "Usage: cmd-test-runner --manifest FILE [--suite compat|contract|backend-pair|paired|policy|oracle|gnu|stress|scenarios|all] [--backend native|wasm] [--native-root DIR] [--wasm-root DIR] [--oracle-image IMAGE] [--oracle-profile FILE] [--command NAME] [--case ID] [--list] [--report-dir DIR] [--jobs N] [--validate-only]\n       cmd-test-runner --seal-oracle sha256:IMAGE-ID [--oracle-profile FILE]"
}

///|
using @testkit {spawn_https_fixture_process}

///|
fn suite_report(
  name : String,
  backend : String,
  start : Int64,
  failures : Array[String],
) -> @testkit.CaseReport {
  {
    id: name,
    command: "suite",
    result: if failures.is_empty() {
      "pass"
    } else {
      "fail"
    },
    verification: if name == "policy" {
      "boundary"
    } else {
      "contract"
    },
    stage: "assertion",
    detail: failures.join("; "),
    platform: @testkit.host_platform(),
    backend,
    source_version: "workspace 0.2.0",
    duration_ms: @async.now() - start,
    observations: ["status", "stdout", "stderr", "file-content"],
    missing_observations: [],
    evidence: None,
  }
}

///|
async fn main {
  @testkit.begin_environment_capture()
  run_driver() catch {
    error => {
      @stdio.stderr.write("infrastructure: " + error.to_string() + "\n")
      @sys.exit(1)
    }
  }
}

///|
// Keep the legacy JSON case identity alongside the typed scenario binding.
fn append_scenario_reports(
  reports : Array[@testkit.CaseReport],
  fixture : @testkit.Case,
  report : @testkit.CaseReport,
) -> Unit {
  reports.push({ ..report, id: fixture.id, })
  reports.push(report)
}

///|
// Stateful scenarios share process and fixture state. The requested job limit
// applies to independent cases; both scenario suites use this serial path.
async fn run_scenario_batch(
  cases : Array[@testkit.Case],
  reports : Array[@testkit.CaseReport],
  jobs : Int32,
  execute : async (@testkit.Case) -> @testkit.CaseReport,
) -> Unit {
  guard jobs > 0 else { fail("scenario job limit must be positive") }
  for fixture in cases {
    append_scenario_reports(reports, fixture, execute(fixture))
  }
}

///|
async fn run_driver() -> Unit {
  let oracle_options = @testkit.parse_oracle_options(@env.args()[1:]) catch {
    error => {
      @stdio.stderr.write(error.to_string() + "\n" + usage() + "\n")
      @sys.exit(2)
      return
    }
  }
  let args = oracle_options.arguments[:]
  if args.get(0) == Some("--mv-test-helper") {
    @mv_scenarios.run_helper(args[1:])
    return
  }
  if args.get(0) == Some("--test-helper") {
    run_test_helper(args[1:])
    return
  }
  if args.get(0) == Some("--http-fixture-server") {
    @testkit.run_http_fixture_process()
    return
  }
  if args.length() == 4 && args[0] == "--https-server" {
    @sys.exit(run_external_https_fixture(args))
    return
  }
  let project_root = workspace_root()
  let registry_path = workspace_path(
    project_root, "tests/registry/registry.json",
  )
  let canonical_corpus_path = workspace_path(
    project_root, "tests/fixtures/runner/cases.json",
  )
  let expected_oracle_profile_path = workspace_path(
    project_root, "tests/runner/image/profile.json",
  )
  let oracle_profile_path = if oracle_options.profile_path ==
    "tests/runner/image/profile.json" {
    expected_oracle_profile_path
  } else {
    workspace_input(project_root, oracle_options.profile_path)
  }
  let http_fixture_directory = workspace_path(
    project_root, "tests/fixtures/http",
  )
  if oracle_options.seal_digest is Some(digest) {
    @testkit.seal_oracle_profile(
      oracle_profile_path,
      digest,
      expected_profile_path=expected_oracle_profile_path,
    )
    return
  }
  let mut manifest_path = canonical_corpus_path
  let mut native_root = workspace_path(
    project_root, "_build/native/release/build",
  )
  let mut wasm_root = workspace_path(project_root, "_build/wasm/release/build")
  let mut oracle_image = "mooncmd-oracle:phase0"
  let suites : Array[String] = []
  let commands : Array[String] = []
  let ids : Array[String] = []
  let mut backend = "native"
  let mut jobs = 4
  let mut list = false
  let mut validate_only = false
  let mut report_dir = workspace_path(
    project_root,
    "test-reports/workspace-" + @async.now().to_string(),
  )
  let mut index = 0
  while index < args.length() {
    let flag = args[index]
    match flag {
      "--list" => list = true
      "--validate-only" => validate_only = true
      "--gnu-diff" => if !suites.contains("gnu") { suites.push("gnu") }
      "--stress" => if !suites.contains("stress") { suites.push("stress") }
      "--manifest"
      | "--native-root"
      | "--wasm-root"
      | "--oracle-image"
      | "--suite"
      | "--backend"
      | "--command"
      | "--case"
      | "--report-dir"
      | "--jobs" => {
        index += 1
        guard args.get(index) is Some(value) else {
          @stdio.stderr.write(usage() + "\n")
          @sys.exit(2)
          return
        }
        match flag {
          "--manifest" => manifest_path = value
          "--native-root" => native_root = value
          "--wasm-root" => wasm_root = value
          "--oracle-image" => oracle_image = value
          "--suite" => if !suites.contains(value) { suites.push(value) }
          "--backend" => backend = value
          "--command" => commands.push(value)
          "--case" => ids.push(value)
          "--report-dir" => report_dir = value
          _ => jobs = @string.parse_int(value) catch { _ => 0 }
        }
      }
      _ => {
        @stdio.stderr.write(usage() + "\n")
        @sys.exit(2)
        return
      }
    }
    index += 1
  }
  if jobs < 1 ||
    !(backend == "native" || backend == "wasm") ||
    suites.any(suite => {
      ![
        "compat", "contract", "backend-pair", "policy", "oracle", "gnu", "stress",
        "scenarios", "paired", "all",
      ].contains(suite)
    }) {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  if suites.is_empty() {
    suites.push("compat")
  }
  let paired = suites.contains("paired")
  if paired {
    guard suites.length() == 1 && backend == "native" else {
      fail(
        "paired runs both backends and must be selected without other suites or --backend wasm",
      )
    }
    suites.clear()
    suites.append(["backend-pair", "contract", "scenarios"])
  }
  if suites.contains("all") {
    suites.clear()
    suites.append([
      "compat", "contract", "backend-pair", "policy", "oracle", "scenarios",
    ])
  }
  manifest_path = workspace_input(project_root, manifest_path)
  native_root = workspace_input(project_root, native_root)
  wasm_root = workspace_input(project_root, wasm_root)
  report_dir = workspace_output(report_dir)
  let (manifest, selected, required_oracle_profiles, registry) = try {
    let registry = @registry.load(registry_path)
    let registry_failures = @registry.validate(registry)
    let registry_source_failures = @registry.validate_source_bindings(
      registry,
      root=project_root,
    )
    let registry_cases = @testkit.load_cases(canonical_corpus_path)
    let registry_case_failures = @registry.validate_case_bindings(
      registry,
      registry_cases.map(item => item.id),
    )
    if !(registry_failures + registry_source_failures + registry_case_failures).is_empty() {
      fail(
        "Test registry validation failed:\n" +
        (registry_failures + registry_source_failures + registry_case_failures).join(
          "\n",
        ),
      )
    }
    let manifest : Manifest = @json.from_json(
      @json.parse(@fs.read_file(manifest_path).text()),
    )
    let all = @testkit.load_cases(manifest_path)
    let selected_binding_failures = @registry.validate_selected_cases(
      registry,
      all,
      root=project_root,
    )
    guard selected_binding_failures.is_empty() else {
      fail(
        "Selected manifest registry validation failed:\n" +
        selected_binding_failures.join("\n"),
      )
    }
    let manifest = { ..manifest, cases: all, }
    let failures = validate_manifest(manifest)
    if !failures.is_empty() {
      fail(failures.join("\n"))
    }
    let available = [..all, ..registered_cohort_cases(registry)]
    let selected = @testkit.select_cases(available, commands, ids).filter(item => {
      case_in_suites(item, suites) &&
      (
        registered_scenario_backend_selected(registry, item, backend, ids) ||
        (
          paired &&
          registered_scenario_backend_selected(registry, item, "wasm", ids)
        )
      )
    })
    if selected.is_empty() {
      fail("empty selection for requested suites")
    }
    for fixture in selected {
      if fixture.oracle == Some(true) && suites.contains("oracle") {
        guard registry.entries.any(entry => {
          entry.case_id == fixture.id && entry.oracle_profile != ""
        }) else {
          fail(
            fixture.id + ": differential requires a registered oracle profile",
          )
        }
      }
    }
    let required_oracle_profiles = registry.entries
      .filter(entry => {
        entry.oracle_profile != "" &&
        selected.any(fixture => {
          entry.case_id == fixture.id ||
          entry.behavior_id == "scenario:" + fixture.id
        })
      })
      .map(entry => entry.oracle_profile)
    (manifest, selected, required_oracle_profiles, registry)
  } catch {
    error => {
      @stdio.stderr.write(error.to_string() + "\n")
      @sys.exit(2)
      return
    }
  }
  if list {
    for fixture in selected {
      let level = fixture.comparison.unwrap_or("differential")
      println("\{fixture.id}\t\{fixture.command}\t\{level}")
    }
    return
  }
  if validate_only {
    println(
      "Manifest valid: \{manifest.commands.length()} commands, \{selected.length()} selected cases",
    )
    return
  }
  let artifact_root = if backend == "wasm" { wasm_root } else { native_root }
  let native_bin_root = if @path.Path(native_root).is_absolute() {
    native_root
  } else {
    @path.Path(project_root).join(Path(native_root)).to_string()
  }
  let wasm_bin_root = if @path.Path(wasm_root).is_absolute() {
    wasm_root
  } else {
    @path.Path(project_root).join(Path(wasm_root)).to_string()
  }
  let bin_root = if @path.Path(artifact_root).is_absolute() {
    artifact_root
  } else {
    @path.Path(project_root).join(Path(artifact_root)).to_string()
  }
  if !@fs.exists(report_dir) {
    @fs.mkdir(report_dir, recursive=true)
  }
  report_dir = @fs.realpath(report_dir)
  let run_started = @async.now()
  let reports : Array[@testkit.CaseReport] = []
  let mut oracle_image_digest = ""
  let mut oracle_versions_hash = ""
  let mut oracle_profile_id = ""
  let mut start_metadata = @testkit.collect_run_metadata(
    "workspace-" + run_started.to_string(),
    manifest_path~,
    case_corpus_path=manifest_path,
    native_root=native_bin_root,
    wasm_root=wasm_bin_root,
    registry_path~,
    policy_path?=if suites.contains("policy") {
      Some(workspace_path(project_root, "tests/fixtures/policy"))
    } else {
      None
    },
    oracle_profile_id="",
    oracle_image_digest="",
    started_at_ms=run_started,
  )
  retain_execution_failure(reports, backend, run_started, () => {
    for suite in suites {
      match suite {
        "compat" | "gnu" | "stress" | "policy" =>
          for fixture in selected.filter(item => item.comparison == Some(suite)) {
            reports.push(
              execute_cohort(
                fixture, bin_root, backend, project_root, wasm_root,
              ),
            )
          }
        "contract" => {
          let cases = selected.filter(item => {
            case_in_suites(item, ["contract"]) &&
            (!paired || paired_single_execution(item))
          })
          for
            execution_backend in (if paired {
              ["native", "wasm"]
            } else {
              [backend]
            }) {
            let backend = execution_backend
            let bin_root = if backend == "wasm" {
              wasm_bin_root
            } else {
              native_bin_root
            }
            let report_dir = if paired {
              report_dir + "/contract-" + backend
            } else {
              report_dir
            }
            if cases.is_empty() {
              continue
            }
            @async.with_task_group(group => {
              let mut base : String? = None
              let mut https_base : String? = None
              if cases.any(item => @testkit.is_network_case(item)) {
                let (child, reader, url) = @testkit.spawn_http_fixture_process(
                  group,
                )
                base = Some(url)
                group.add_defer(() => {
                  reader.close()
                  child.cancel()
                  @async.protect_from_cancel(() => ignore(child.wait()))
                })
              }
              if cases.any(item => {
                  item.platform_applies() &&
                  item.args.any(arg => arg.contains("${HTTPS_BASE}"))
                }) {
                let root = @fs.tmpdir(prefix="mooncmd-contract-https-")
                let (child, url) = spawn_https_fixture_process(
                  group,
                  root,
                  fixture_directory=http_fixture_directory,
                )
                https_base = Some(url)
                group.add_defer(() => {
                  child.cancel()
                  @async.protect_from_cancel(() => ignore(child.wait()))
                  @fs.rmdir(root, recursive=true)
                })
              }
              let tasks : Array[async () -> Unit] = cases.map(item => {
                () => {
                  let transformed = match https_base {
                    Some(url) =>
                      {
                        ..item,
                        args: item.args.map(arg => {
                          arg.replace_all(old="${HTTPS_BASE}", new=url)
                        }),
                      }
                    None => item
                  }
                  reports.push(
                    @testkit.execute_contract(
                      transformed,
                      bin_root,
                      backend == "wasm",
                      report_dir,
                      http_base?=base,
                    ),
                  )
                }
              })
              ignore(@async.all(tasks, max_concurrent=jobs))
            })
          }
        }
        "backend-pair" => {
          let scenarios = selected.filter(item => {
            item.comparison == Some("scenario") &&
            case_in_suites(item, ["backend-pair"])
          })
          run_scenario_batch(scenarios, reports, jobs, fixture => {
            execute_scenario_backend_pair(
              fixture,
              native_bin_root,
              wasm_bin_root,
              report_dir,
              side_reports?=if paired { Some(reports) } else { None },
            )
          })
          let cases = selected.filter(item => {
            item.comparison == Some("contract") &&
            case_in_suites(item, ["backend-pair"])
          })
          if cases.is_empty() {
            continue
          }
          @async.with_task_group(group => {
            let mut base : String? = None
            let mut https_base : String? = None
            if cases.any(item => @testkit.is_network_case(item)) {
              let (child, reader, url) = @testkit.spawn_http_fixture_process(
                group,
              )
              base = Some(url)
              group.add_defer(() => {
                reader.close()
                child.cancel()
                @async.protect_from_cancel(() => ignore(child.wait()))
              })
            }
            if cases.any(item => {
                item.platform_applies() &&
                item.args.any(arg => arg.contains("${HTTPS_BASE}"))
              }) {
              let root = @fs.tmpdir(prefix="mooncmd-pair-https-")
              let (child, url) = spawn_https_fixture_process(
                group,
                root,
                fixture_directory=http_fixture_directory,
              )
              https_base = Some(url)
              group.add_defer(() => {
                child.cancel()
                @async.protect_from_cancel(() => ignore(child.wait()))
                @fs.rmdir(root, recursive=true)
              })
            }
            let tasks : Array[async () -> Unit] = cases.map(item => {
              () => {
                let item = match https_base {
                  Some(url) =>
                    {
                      ..item,
                      args: item.args.map(arg => {
                        arg.replace_all(old="${HTTPS_BASE}", new=url)
                      }),
                    }
                  None => item
                }
                reports.push(
                  execute_backend_pair(
                    item,
                    native_bin_root,
                    wasm_bin_root,
                    report_dir,
                    http_base?=base,
                    side_reports?=if paired { Some(reports) } else { None },
                  ),
                )
              }
            })
            ignore(@async.all(tasks, max_concurrent=jobs))
          })
        }
        "oracle" => {
          let oracle_identity = try {
            oracle_profile_id = @testkit.read_oracle_profile(
                expected_oracle_profile_path,
              ).id
            start_metadata = { ..start_metadata, oracle_profile_id, }
            @testkit.verify_oracle_image(
              oracle_image,
              profile_path=oracle_profile_path,
              expected_profile_path=expected_oracle_profile_path,
              required_profile_ids=required_oracle_profiles,
            )
          } catch {
            error => {
              for
                fixture in selected.filter(item => {
                  case_in_suites(item, ["oracle"])
                }) {
                let base = suite_report(fixture.id, backend, @async.now(), [])
                let report = {
                  ..base,
                  command: fixture.command,
                  result: "infra",
                  verification: if fixture.expected_rejection is Some(_) {
                    "boundary"
                  } else {
                    "differential"
                  },
                  stage: "oracle-preflight",
                  detail: error.to_string(),
                  observations: [],
                  missing_observations: @testkit.contract_observations(fixture),
                }
                reports.push(report)
                if fixture.comparison == Some("oracle-scenario") {
                  reports.push({ ..report, id: "scenario:" + fixture.id, })
                }
              }
              continue
            }
          }
          oracle_image_digest = oracle_identity.digest
          oracle_profile_id = oracle_identity.profile_id
          oracle_versions_hash = @testkit.sha256_text(oracle_identity.versions)
          start_metadata = @testkit.with_oracle_identity(
            start_metadata, oracle_identity,
          )
          oracle_image = oracle_identity.digest
          println(
            "oracle identity: \{oracle_identity.profile_id}@\{oracle_identity.digest}",
          )
          let docker_user = @testkit.docker_user()
          run_scenario_batch(
            selected.filter(item => item.comparison == Some("oracle-scenario")),
            reports,
            jobs,
            fixture => {
              execute_scenario(
                fixture,
                bin_root,
                backend == "wasm",
                report_dir,
                oracle_image~,
              )
            },
          )
          let selected = selected.filter(item => {
            item.comparison is None ||
            item.comparison == Some("differential") ||
            item.comparison == Some("exact") ||
            item.comparison == Some("normalized") ||
            item.oracle == Some(true) ||
            item.expected_rejection is Some(_)
          })
          if selected.is_empty() {
            continue
          }
          @async.with_task_group(group => {
            let mut http_base = ""
            let mut https_base = ""
            let fixture_root = @fs.tmpdir(prefix="mooncmd-oracle-http-")
            defer @fs.rmdir(fixture_root, recursive=true)
            if selected.any(item => @testkit.is_network_case(item)) {
              let (child, reader, url) = @testkit.spawn_http_fixture_process(
                group,
              )
              http_base = url
              group.add_defer(() => {
                reader.close()
                child.cancel()
                @async.protect_from_cancel(() => ignore(child.wait()))
              })
            }
            if selected.any(item => {
                item.args.any(arg => arg.contains("${HTTPS_BASE}"))
              }) {
              let (child, url) = spawn_https_fixture_process(
                group,
                fixture_root,
                fixture_directory=http_fixture_directory,
              )
              https_base = url
              group.add_defer(() => {
                child.cancel()
                @async.protect_from_cancel(() => ignore(child.wait()))
              })
            }
            let tasks : Array[async () -> Unit] = selected.map(fixture => {
              () => {
                let begin = @async.now()
                if !fixture.platform_applies() {
                  let report = suite_report(fixture.id, backend, begin, [])
                  reports.push({
                    ..report,
                    command: fixture.command,
                    result: "skip",
                    verification: "differential",
                    stage: "platform",
                    detail: "case excludes this platform",
                    observations: [],
                  })
                  return
                }
                let failures = run_case(
                  fixture,
                  bin_root,
                  oracle_image,
                  http_base,
                  https_base,
                  backend == "wasm",
                  report_dir,
                  docker_user,
                ) catch {
                  error => ["infrastructure: " + error.to_string()]
                }
                let report = suite_report(fixture.id, backend, begin, failures)
                let infrastructure = failures.any(message => {
                  message.contains("failed to start") ||
                  message.has_prefix("infrastructure:")
                })
                let stage = if failures.any(message => {
                    message.contains("cleanup")
                  }) {
                  "cleanup"
                } else if failures.any(message => message.contains("timeout:")) {
                  "timeout"
                } else if failures.any(message => {
                    message.contains("oracle failed") ||
                    message.contains("oracle unavailable")
                  }) {
                  "oracle"
                } else if infrastructure {
                  "infrastructure"
                } else if failures.is_empty() {
                  "complete"
                } else {
                  "assertion"
                }
                reports.push({
                  ..report,
                  command: fixture.command,
                  source_version: fixture.source_version.unwrap_or(
                    oracle_identity.image + "@" + oracle_identity.digest,
                  ),
                  result: if infrastructure {
                    "infra"
                  } else {
                    report.result
                  },
                  verification: if fixture.expected_rejection is Some(_) {
                    "boundary"
                  } else {
                    "differential"
                  },
                  stage,
                  observations: if failures.is_empty() {
                    [
                      "status",
                      "stdout",
                      "stderr",
                      "content",
                      "type",
                      ..fixture.observe.unwrap_or([]),
                    ]
                  } else {
                    []
                  },
                  missing_observations: if infrastructure {
                    fixture.observe.unwrap_or([])
                  } else {
                    []
                  },
                  evidence: if report.result == "pass" {
                    None
                  } else {
                    Some(report_dir + "/" + fixture.id)
                  },
                })
              }
            })
            ignore(@async.all(tasks, max_concurrent=jobs))
          })
        }
        _ =>
          for
            execution_backend in (if paired {
              ["native", "wasm"]
            } else {
              [backend]
            }) {
            let backend = execution_backend
            let bin_root = if backend == "wasm" {
              wasm_bin_root
            } else {
              native_bin_root
            }
            let report_dir = if paired {
              report_dir + "/scenarios-" + backend
            } else {
              report_dir
            }
            let cases = selected.filter(item => {
              item.comparison == Some("scenario") &&
              (!paired || paired_single_execution(item)) &&
              registered_scenario_backend_selected(registry, item, backend, ids)
            })
            if cases.is_empty() {
              continue
            }
            run_scenario_batch(cases, reports, jobs, fixture => {
              execute_scenario(fixture, bin_root, backend == "wasm", report_dir)
            })
          }
      }
    }
  })
  let metadata = @testkit.collect_run_metadata(
    "workspace-" + @async.now().to_string(),
    manifest_path~,
    case_corpus_path=manifest_path,
    native_root=native_bin_root,
    wasm_root=wasm_bin_root,
    registry_path~,
    policy_path?=if suites.contains("policy") {
      Some(workspace_path(project_root, "tests/fixtures/policy"))
    } else {
      None
    },
    oracle_profile_id~,
    oracle_image_digest~,
    started_at_ms=run_started,
    ended_at_ms=@async.now(),
  )
  let metadata = @testkit.with_oracle_versions_hash(
    metadata, oracle_versions_hash,
  )
  let metadata = @testkit.finalize_run_metadata(start_metadata, metadata)
  if paired {
    for
      role in [
        "contract-native", "contract-wasm", "scenarios-native", "scenarios-wasm",
        "backend-pair",
      ] {
      @testkit.write_reports_with_metadata(
        report_dir + "/" + role,
        paired_role_reports(reports, selected, role),
        metadata,
      )
    }
  } else {
    @testkit.write_reports_with_metadata(report_dir, reports, metadata)
  }
  for report in reports {
    println(
      "\{report.result} \{report.verification} \{report.id} \{report.duration_ms}ms \{report.detail}",
    )
  }
  println(
    "semantic passes: \{reports.filter(item => item.semantic_pass()).length()}; report: \{report_dir}",
  )
  if reports.any(item => item.result == "fail" || item.result == "infra") ||
    metadata.reproducibility_status != "complete" {
    @sys.exit(1)
  }
}

///|
fn paired_role_reports(
  reports : Array[@testkit.CaseReport],
  fixtures : Array[@testkit.Case],
  role : String,
) -> Array[@testkit.CaseReport] {
  reports.filter(report => {
    if role == "backend-pair" {
      return report.verification == "backend-pair"
    }
    let scenario = fixtures.any(fixture => {
      fixture.comparison == Some("scenario") &&
      (report.id == fixture.id || report.id == "scenario:" + fixture.id)
    })
    let backend = if role.has_suffix("-wasm") { "wasm" } else { "native" }
    report.backend == backend &&
    report.verification != "backend-pair" &&
    scenario == role.has_prefix("scenarios-")
  })
}

///|
fn paired_single_execution(fixture : @testkit.Case) -> Bool {
  !case_in_suites(fixture, ["backend-pair"]) || !fixture.platform_applies()
}
