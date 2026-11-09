///|
fn usage() -> String {
  "Usage: cmd-test-runner --manifest FILE [--suite functional|metadata|compat|contract|policy|oracle|stress|scenarios|all] [--published-manifest FILE] [--moonx PATH] [--wasm-root DIR] [--oracle-image IMAGE] [--oracle-profile FILE] [--command NAME] [--case ID] [--list] [--report-dir DIR] [--jobs N] [--validate-only]\n       cmd-test-runner --seal-oracle sha256:IMAGE-ID [--oracle-profile FILE]"
}

///|
using @harness {spawn_https_fixture_process}

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
  reports : Array[@harness.CaseReport],
  fixture : @harness.Case,
  report : @harness.CaseReport,
) -> Unit {
  @harness.append_report(reports, { ..report, id: fixture.id, })
}

///|
// Only reviewed scenarios with private directories, servers and process state
// opt into concurrency. Every event still executes its own steps in order.
async fn run_scenario_batch(
  cases : Array[@harness.Case],
  reports : Array[@harness.CaseReport],
  jobs : Int32,
  execute : async (@harness.Case) -> @harness.CaseReport,
) -> Unit {
  guard jobs > 0 else { fail("scenario job limit must be positive") }
  let independent : Array[async () -> Unit] = []
  let serial : Array[@harness.Case] = []
  for fixture in cases {
    if fixture.isolated == Some(true) {
      independent.push(() => {
        append_scenario_reports(reports, fixture, execute(fixture))
      })
    } else {
      serial.push(fixture)
    }
  }
  ignore(@async.all(independent, max_concurrent=jobs.min(4)))
  for fixture in serial {
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
    if raw[1:] is ["tee-modes", program, work] {
      @filesystem.check_tee_modes(program, [], work)
      return
    }
    let status = @harness.run_option_child(raw[1:])
    if status != 0 {
      @sys.exit(status)
    }
    return
  }
  let oracle_options = @harness.parse_oracle_options(@env.args()[1:]) catch {
    error => {
      @stdio.stderr.write(error.to_string() + "\n" + usage() + "\n")
      @sys.exit(2)
      return
    }
  }
  let args = expand_oracle_selection(oracle_options.arguments)
  if args.get(0) == Some("--mv-test-helper") {
    @filesystem.run_helper(args[1:])
    return
  }
  if args.get(0) == Some("--test-helper") {
    @scenarios.run_test_helper(args[1:])
    return
  }
  if args.get(0) == Some("--http-fixture-server") {
    @harness.run_http_fixture_process()
    return
  }
  if args.length() == 4 && args[0] == "--https-server" {
    @sys.exit(run_external_https_fixture(args))
    return
  }
  let project_root = workspace_root()
  if args is ["--select-oracle", base, head, output] {
    select_oracle_changes(project_root, base, head, output)
    return
  }
  let registry_path = workspace_path(project_root, "tests/cases/index.json")
  let canonical_corpus_path = workspace_path(
    project_root, "tests/cases/manifest.json",
  )
  let expected_oracle_profile_path = workspace_path(
    project_root, "tests/fixtures/oracle/profile.json",
  )
  let oracle_profile_path = if oracle_options.profile_path ==
    "tests/fixtures/oracle/profile.json" {
    expected_oracle_profile_path
  } else {
    workspace_input(project_root, oracle_options.profile_path)
  }
  let http_fixture_directory = workspace_path(
    project_root, "tests/fixtures/http",
  )
  if oracle_options.seal_digest is Some(digest) {
    @harness.seal_oracle_profile(
      oracle_profile_path,
      digest,
      expected_profile_path=expected_oracle_profile_path,
    )
    return
  }
  let options = parse_driver_options(args, project_root, canonical_corpus_path)
  let mut manifest_path = options.manifest_path
  let published_manifest = options.published_manifest
  let moonx = options.moonx
  let mut wasm_root = options.wasm_root
  let mut oracle_image = options.oracle_image
  let suites = options.suites
  let commands = options.commands
  let ids = options.ids
  let mut jobs = options.jobs
  let list = options.list
  let validate_only = options.validate_only
  let mut report_dir = options.report_dir
  let backend = "wasm"
  manifest_path = workspace_input(project_root, manifest_path)
  wasm_root = workspace_input(project_root, wasm_root)
  report_dir = workspace_output(report_dir)
  let published = match published_manifest {
    Some(path) =>
      Some(load_published_commands(workspace_input(project_root, path), moonx))
    None => {
      @harness.configure_commands(Map([]), "moonrun")
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
    let registry = @catalog.load(registry_path)
    let registry_failures = @catalog.validate(registry)
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
    let all = @harness.load_cases(manifest_path)
    let all = match published {
      Some((_, ids)) => @harness.select_cases(all, [], ids)
      None => all
    }
    let manifest = { ..manifest, cases: all, }
    if published is None {
      validate_case_inputs(project_root, all)
      @harness.validate_local_assertions(
        all,
        registry.entries
        .filter(row => row.implementation == "stateful-scenario")
        .map(row => {
          row.behavior_id
          .strip_prefix("scenario:")
          .map(StringView::to_owned)
          .unwrap_or(row.case_id)
        }),
      )
    }
    let failures = validate_manifest(manifest)
    if !failures.is_empty() {
      fail(failures.join("\n"))
    }
    let available = [
      ..all,
      ..registered_cohort_cases(registry),
      ..metadata_cases(),
    ]
    let selected = @harness.select_cases(available, commands, ids).filter(item => {
      case_in_suites(item, suites) && @harness.command_available(item.command)
    })
    if selected.is_empty() {
      fail("empty selection for requested suites")
    }
    require_oracle_bindings(selected, registry)
    let required_oracle_profiles = registry.entries
      .filter(entry => {
        entry.oracle_profile != "" &&
        selected.any(fixture => {
          entry.case_id == fixture.id ||
          entry.aliases.contains(fixture.id) ||
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
  guard !@fs.exists(report_dir + "/selected-cases.json") &&
    !@fs.exists(report_dir + "/run.json") else {
    fail(
      "choose a fresh report directory; preserve previous definitions/results",
    )
  }
  let definition_text = (
      {
        "schema": 1,
        "cases": ToJson::to_json(selected),
        "metadata_contracts": @harness.metadata_contract_snapshot(selected),
        "prepared_at_ms": @async.now(),
      } : Json).stringify(indent=2) +
    "\n"
  @fs.write_file(report_dir + "/selected-cases.json", definition_text)
  let run_started = @async.now()
  let reports : Array[@harness.CaseReport] = []
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
            @harness.append_report(
              reports,
              metadata_report(fixture.command, bin_root, backend, report_dir),
            )
          }
        "compat" | "stress" | "policy" =>
          for fixture in selected.filter(item => item.comparison == Some(suite)) {
            append_scenario_reports(
              reports,
              fixture,
              @scenarios.execute_cohort(
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
            if cases.any(item => @harness.is_network_case(item)) {
              let (child, reader, url) = @harness.spawn_http_fixture_process(
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
                @harness.append_report(
                  reports,
                  if published is None &&
                    ["release-metadata-rg-help", "compat-catalog-line-277"].contains(
                      transformed.id,
                    ) {
                    let checked = metadata_report(
                      transformed.command,
                      bin_root,
                      backend,
                      report_dir,
                      fixture=transformed,
                    )
                    { ..checked, id: transformed.id, }
                  } else {
                    @harness.execute_contract(
                      transformed,
                      bin_root,
                      report_dir,
                      http_base?=base,
                    )
                  },
                )
              }
            })
            run_scheduled_tasks(cases, tasks, jobs)
          })
        }
        "oracle" => {
          let oracle_identity = @harness.verify_oracle_image(
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
                let base = @harness.suite_report(
                  fixture.id,
                  backend,
                  @async.now(),
                  [],
                )
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
                  missing_observations: @harness.contract_observations(fixture),
                }
                @harness.append_report(reports, report)
              }
              continue
            }
          }
          oracle_image = oracle_identity.digest
          println(
            "oracle identity: \{oracle_identity.profile_id}@\{oracle_identity.digest}",
          )
          @harness.with_oracle_workers(report_dir, oracle_image, 2, () => {
            let docker_user = @harness.docker_user()
            run_scenario_batch(
              selected.filter(item => {
                case_in_suites(item, ["oracle"]) &&
                [Some("scenario"), Some("oracle-scenario")].contains(
                  item.comparison,
                )
              }),
              reports,
              jobs,
              fixture => {
                @scenarios.execute_scenario(
                  fixture,
                  bin_root,
                  report_dir,
                  oracle_image~,
                )
              },
            )
            let selected = selected.filter(item => {
              case_in_suites(item, ["oracle"]) &&
              ![Some("scenario"), Some("oracle-scenario")].contains(
                item.comparison,
              )
            })
            if selected.is_empty() && !suites.contains("metadata") {
              return
            }
            @async.with_task_group(group => {
              let mut http_base = ""
              let mut https_base = ""
              let fixture_root = @fs.tmpdir(prefix="mooncmd-oracle-http-")
              defer @fs.rmdir(fixture_root, recursive=true)
              if selected.any(item => @harness.is_network_case(item)) {
                let (child, reader, url) = @harness.spawn_http_fixture_process(
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
                    let report = @harness.suite_report(
                      fixture.id,
                      backend,
                      begin,
                      [],
                    )
                    @harness.append_report(reports, {
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
                  let outcome = run_case(
                    fixture, bin_root, oracle_image, http_base, https_base, report_dir,
                    docker_user,
                  ) catch {
                    error =>
                      {
                        failures: ["infrastructure: " + error.to_string()],
                        local_contract: None,
                      }
                  }
                  let failures = outcome.failures
                  let report = @harness.suite_report(
                    fixture.id,
                    backend,
                    begin,
                    failures,
                  )
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
                  @harness.append_report(reports, {
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
                      let observed = [
                        "status",
                        "stdout",
                        "stderr",
                        "content",
                        "type",
                        ..fixture.observe.unwrap_or([]),
                      ]
                      if outcome.local_contract is Some(receipt) {
                        for dimension in receipt.observations {
                          if !observed.contains(dimension) {
                            observed.push(dimension)
                          }
                        }
                      }
                      observed
                    } else {
                      []
                    },
                    missing_observations: if infrastructure {
                      fixture.observe.unwrap_or([])
                    } else {
                      []
                    },
                    local_contract: outcome.local_contract,
                    evidence: if report.result == "pass" {
                      None
                    } else {
                      Some(report_dir + "/" + fixture.id)
                    },
                  })
                }
              })
              run_scheduled_tasks(selected, tasks, jobs.min(2))
            })
          })
        }
        _ => {
          let cases = selected.filter(item => {
            item.comparison == Some("scenario") &&
            !(suites.contains("oracle") && case_in_suites(item, ["oracle"]))
          })
          run_scenario_batch(cases, reports, jobs, fixture => {
            @scenarios.execute_scenario(fixture, bin_root, report_dir)
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
  let integrity_errors = @harness.result_integrity_errors(selected, reports)
  if !integrity_errors.is_empty() {
    @harness.append_report(reports, {
      ..@harness.suite_report(
        "runner:result-integrity", backend, run_started, integrity_errors,
      ),
      result: "infra",
    })
  }
  @harness.write_reports(report_dir, reports)
  println(
    "semantic passes: \{reports.filter(item => item.semantic_pass()).length()}; report: \{report_dir}",
  )
  if reports.any(item => item.result == "fail" || item.result == "infra") {
    @sys.exit(1)
  }
}

///|
// A declared differential route must be complete even when this host runs
// only its independent local assertions. Oracle execution remains separate.
fn require_oracle_bindings(
  selected : Array[@harness.Case],
  registry : @catalog.Registry,
) -> Unit raise Failure {
  for fixture in selected {
    if case_in_suites(fixture, ["oracle"]) {
      guard registry.entries.any(entry => {
        (entry.case_id == fixture.id || entry.aliases.contains(fixture.id)) &&
        entry.oracle_profile != ""
      }) else {
        fail(fixture.id + ": differential requires a registered oracle profile")
      }
    }
  }
}
