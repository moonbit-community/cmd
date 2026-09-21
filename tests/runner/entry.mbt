///|
fn usage() -> String {
  "Usage: cmd-test-runner --manifest FILE [--suite compat|contract|policy|oracle|gnu|stress|scenarios|all] [--backend native|wasm] [--native-root DIR] [--wasm-root DIR] [--oracle-image IMAGE] [--command NAME] [--case ID] [--list] [--report-dir DIR] [--jobs N] [--validate-only]"
}

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
    observations: ["legacy-assertions"],
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
async fn run_driver() -> Unit {
  let args = @env.args()[1:]
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
  let mut manifest_path = "tests/fixtures/runner/cases.json"
  let mut native_root = "_build/native/release/build"
  let mut wasm_root = "_build/wasm/release/build"
  let mut oracle_image = "mooncmd-oracle:phase0"
  let suites : Array[String] = []
  let commands : Array[String] = []
  let ids : Array[String] = []
  let mut backend = "native"
  let mut jobs = 4
  let mut list = false
  let mut validate_only = false
  let mut report_dir = "test-reports/workspace-\{@async.now()}"
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
        "compat", "contract", "policy", "oracle", "gnu", "stress", "scenarios", "all",
      ].contains(suite)
    }) {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  if suites.is_empty() {
    suites.push("compat")
  }
  if suites.contains("all") {
    suites.clear()
    suites.append(["compat", "contract", "policy", "oracle", "scenarios"])
  }
  let (manifest, selected) = try {
    let manifest : Manifest = @json.from_json(
      @json.parse(@fs.read_file(manifest_path).text()),
    )
    let all = @testkit.load_cases(manifest_path)
    let manifest = { ..manifest, cases: all, }
    let failures = validate_manifest(manifest)
    if !failures.is_empty() {
      fail(failures.join("\n"))
    }
    let available = [..all, ..cohort_cases()]
    let selected = @testkit.select_cases(available, commands, ids).filter(item => {
      case_in_suites(item, suites)
    })
    if selected.is_empty() {
      fail("empty selection for requested suites")
    }
    (manifest, selected)
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
  let project_root = @fs.realpath(".")
  let artifact_root = if backend == "wasm" { wasm_root } else { native_root }
  let bin_root = if @path.Path(artifact_root).is_absolute() {
    artifact_root
  } else {
    @path.Path(project_root).join(Path(artifact_root)).to_string()
  }
  if !@fs.exists(report_dir) {
    @fs.mkdir(report_dir, recursive=true)
  }
  report_dir = @fs.realpath(report_dir)
  let reports : Array[@testkit.CaseReport] = []
  for suite in suites {
    match suite {
      "compat" | "gnu" | "stress" | "policy" =>
        for fixture in selected.filter(item => item.comparison == Some(suite)) {
          reports.push(
            execute_cohort(fixture, bin_root, backend, project_root, wasm_root),
          )
        }
      "contract" => {
        let cases = selected.filter(item => {
          item.comparison == Some("contract") ||
          item.expected_rejection is Some(_)
        })
        if cases.is_empty() {
          continue
        }
        @async.with_task_group(group => {
          let mut base : String? = None
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
          let tasks : Array[async () -> @testkit.CaseReport] = cases.map(item => {
            () => {
              @testkit.execute_contract(
                item,
                bin_root,
                backend == "wasm",
                report_dir,
                http_base?=base,
              )
            }
          })
          reports.append(@async.all(tasks, max_concurrent=jobs))
        })
      }
      "oracle" => {
        let docker_user = @testkit.docker_user()
        for
          fixture in selected.filter(item => {
            item.comparison == Some("oracle-scenario")
          }) {
          reports.push(
            execute_scenario(
              fixture,
              bin_root,
              backend == "wasm",
              report_dir,
              oracle_image~,
            ),
          )
        }
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
            let (child, url) = spawn_https_fixture_process(group, fixture_root)
            https_base = url
            group.add_defer(() => {
              child.cancel()
              @async.protect_from_cancel(() => ignore(child.wait()))
            })
          }
          let tasks : Array[async () -> @testkit.CaseReport] = selected.map(fixture => {
            () => {
              let begin = @async.now()
              if !fixture.platform_applies() {
                let report = suite_report(fixture.id, backend, begin, [])
                return {
                  ..report,
                  command: fixture.command,
                  result: "skip",
                  verification: "differential",
                  stage: "platform",
                  detail: "case excludes this platform",
                  observations: [],
                }
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
              let stage = if failures.any(message => message.contains("cleanup")) {
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
              return {
                ..report,
                command: fixture.command,
                source_version: fixture.source_version.unwrap_or(oracle_image),
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
              }
            }
          })
          reports.append(@async.all(tasks, max_concurrent=jobs))
        })
      }
      _ => {
        let cases = selected.filter(item => item.comparison == Some("scenario"))
        if cases.is_empty() {
          continue
        }
        for fixture in cases {
          reports.push(
            execute_scenario(fixture, bin_root, backend == "wasm", report_dir),
          )
        }
      }
    }
  }
  @testkit.write_reports(report_dir, reports)
  for report in reports {
    println(
      "\{report.result} \{report.verification} \{report.id} \{report.duration_ms}ms \{report.detail}",
    )
  }
  println(
    "semantic passes: \{reports.filter(item => item.semantic_pass()).length()}; report: \{report_dir}",
  )
  if reports.any(item => item.result == "fail" || item.result == "infra") {
    @sys.exit(1)
  }
}
