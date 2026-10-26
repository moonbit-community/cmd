///|
fn usage() -> String {
  "Usage: cmd-test-runner --manifest FILE [--suite functional|metadata|compat|contract|policy|oracle|stress|scenarios|all] [--backend wasm] [--published-manifest FILE] [--moonx PATH] [--wasm-root DIR] [--oracle-image IMAGE] [--oracle-profile FILE] [--command NAME] [--case ID] [--list] [--report-dir DIR] [--jobs N] [--validate-only]\n       cmd-test-runner --seal-oracle sha256:IMAGE-ID [--oracle-profile FILE]"
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
  run_driver() catch {
    error => {
      @stdio.stderr.write("infrastructure: " + error.to_string() + "\n")
      @sys.exit(1)
    }
  }
}

///|
// One scenario execution produces one result using its selectable case ID.
fn append_scenario_reports(
  reports : Array[@testkit.CaseReport],
  fixture : @testkit.Case,
  report : @testkit.CaseReport,
) -> Unit {
  @testkit.append_report(reports, { ..report, id: fixture.id, })
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
  let raw = @env.args()[1:]
  if @env.get_env_var("CMD_RG_PREPROCESSOR") is Some(mode) {
    run_rg_preprocessor(mode, raw)
    return
  }
  if raw.get(0) == Some("--metadata-observer") {
    metadata_observer(raw[1:])
    return
  }
  if raw.get(0) == Some("--option-test-helper") {
    let status = @testkit.run_option_child(raw[1:])
    if status != 0 {
      @sys.exit(status)
    }
    return
  }
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
  let mut published_manifest : String? = None
  let mut moonx = "moonx"
  let mut wasm_root = workspace_path(project_root, "_build/wasm/release/build")
  let mut oracle_image = "mooncmd-oracle:phase0"
  let suites : Array[String] = []
  let commands : Array[String] = []
  let ids : Array[String] = []
  let mut backend = "wasm"
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
      "--stress" => if !suites.contains("stress") { suites.push("stress") }
      "--manifest"
      | "--published-manifest"
      | "--moonx"
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
          "--published-manifest" => published_manifest = Some(value)
          "--moonx" => moonx = value
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
    backend != "wasm" ||
    suites.any(suite => {
      ![
        "functional", "metadata", "compat", "contract", "policy", "oracle", "stress",
        "scenarios", "all",
      ].contains(suite)
    }) {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  if suites.is_empty() {
    suites.push("functional")
  }
  if suites.contains("functional") || suites.contains("all") {
    let oracle = suites.contains("oracle") || suites.contains("all")
    suites.clear()
    suites.append([
      "metadata", "compat", "contract", "scenarios", "policy", "stress",
    ])
    if oracle {
      suites.push("oracle")
    }
  }
  manifest_path = workspace_input(project_root, manifest_path)
  wasm_root = workspace_input(project_root, wasm_root)
  report_dir = workspace_output(report_dir)
  let published = match published_manifest {
    Some(path) =>
      Some(load_published_commands(workspace_input(project_root, path), moonx))
    None => {
      @testkit.configure_commands(Map([]), "moonrun")
      None
    }
  }
  if published is Some((path, _)) {
    manifest_path = path
  }
  if published is Some(_) {
    jobs = 1
  }
  let (manifest, selected, required_oracle_profiles) = try {
    let registry = @registry.load(registry_path)
    let registry_failures = @registry.validate(registry)
    guard registry_failures.is_empty() else {
      fail(registry_failures.join("\n"))
    }
    let manifest : Manifest = @json.from_json(
      @json.parse(
        @fs.read_file(
          if published is Some(_) {
            canonical_corpus_path
          } else {
            manifest_path
          },
        ).text(),
      ),
    )
    let all = @testkit.load_cases(manifest_path)
    let all = match published {
      Some((_, ids)) => {
        for id in ids {
          guard all.any(item => item.id == id) else {
            fail("published case does not exist: " + id)
          }
        }
        all.filter(item => ids.contains(item.id))
      }
      None => all
    }
    let manifest = { ..manifest, cases: all, }
    let failures = validate_manifest(manifest)
    if !failures.is_empty() {
      fail(failures.join("\n"))
    }
    let available = [
      ..all,
      ..registered_cohort_cases(registry),
      ..metadata_cases(),
    ]
    let selected = @testkit.select_cases(available, commands, ids).filter(item => {
      case_in_suites(item, suites) && @testkit.command_available(item.command)
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
    (manifest, selected, required_oracle_profiles)
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
  let bin_root = @fs.realpath(wasm_root) catch { _ => wasm_root }
  if !@fs.exists(report_dir) {
    @fs.mkdir(report_dir, recursive=true)
  }
  report_dir = @fs.realpath(report_dir)
  let run_started = @async.now()
  let reports : Array[@testkit.CaseReport] = []
  let stage_durations : Map[String, Int64] = Map([])
  retain_execution_failure(reports, backend, run_started, () => {
    if published is Some(_) {
      prime_published_commands(commands, reports)
    }
    for suite in suites {
      let started = @async.now()
      match suite {
        "metadata" =>
          for
            fixture in selected.filter(item => {
              item.comparison == Some("metadata")
            }) {
            @testkit.append_report(
              reports,
              metadata_report(fixture.command, bin_root, backend, report_dir),
            )
          }
        "compat" | "stress" | "policy" =>
          for fixture in selected.filter(item => item.comparison == Some(suite)) {
            @testkit.append_report(
              reports,
              execute_cohort(
                fixture, bin_root, backend, project_root, wasm_root,
              ),
            )
          }
        "contract" => {
          let cases = selected.filter(item => {
            case_in_suites(item, ["contract"]) &&
            !(suites.contains("oracle") && case_in_suites(item, ["oracle"]))
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
                @testkit.append_report(
                  reports,
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
            run_scheduled_tasks(cases, tasks, jobs)
          })
        }
        "oracle" => {
          let oracle_identity = @testkit.verify_oracle_image(
            oracle_image,
            profile_path=oracle_profile_path,
            expected_profile_path=expected_oracle_profile_path,
            required_profile_ids=required_oracle_profiles,
          ) catch {
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
                @testkit.append_report(reports, report)
              }
              continue
            }
          }
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
            case_in_suites(item, ["oracle"]) &&
            item.comparison != Some("oracle-scenario")
          })
          if selected.is_empty() && !suites.contains("metadata") {
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
                  @testkit.append_report(reports, {
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
                @testkit.append_report(reports, {
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
            run_scheduled_tasks(selected, tasks, jobs)
          })
        }
        _ => {
          let cases = selected.filter(item => {
            item.comparison == Some("scenario")
          })
          run_scenario_batch(cases, reports, jobs, fixture => {
            execute_scenario(fixture, bin_root, true, report_dir)
          })
        }
      }
      stage_durations[suite] = @async.now() - started
    }
  })
  @fs.write_file(
    report_dir + "/stages.json",
    ToJson::to_json(stage_durations).stringify(indent=2) + "\n",
  )
  @testkit.write_reports(report_dir, reports)
  println(
    "semantic passes: \{reports.filter(item => item.semantic_pass()).length()}; report: \{report_dir}",
  )
  if reports.any(item => item.result == "fail" || item.result == "infra") {
    @sys.exit(1)
  }
}
