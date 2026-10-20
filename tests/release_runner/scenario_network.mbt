///|
/// A shared network scenario invokes both commands even though its stable case
/// identity belongs to curl. Include both exact assets in execution provenance.
fn network_scenario_commands(fixture : ReleaseCase) -> Array[String] {
  if @network_scenarios.supports(fixture.id) {
    ["curl", "wget"]
  } else {
    [fixture.command]
  }
}

///|
fn published_network_executor(
  manifest : ReleaseManifest,
  moonx : String,
  timeout_ms : Int32,
  receipt_directory : String,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> @network_scenarios.Executor {
  let sequence = Ref(0)
  {
    invoke: invocation => {
      guard ["curl", "wget"].contains(invocation.command) else {
        fail("network scenario attempted an unregistered command")
      }
      guard release_includes(manifest, invocation.command) else {
        fail(
          "network scenario command is outside release scope: " +
          invocation.command,
        )
      }
      guard find_command(manifest, invocation.command) is Some(row) else {
        fail("network scenario has no exact release coordinate")
      }
      let coordinate = row.package_name + "@" + row.version
      let args = [coordinate, "--", ..invocation.args]
      let environment = controlled_environment(invocation.environment)
      let launch : CandidateInvocation = {
        program: moonx,
        args,
        timeout_ms,
        stdin: invocation.stdin,
        cwd: invocation.cwd,
        environment,
      }
      let receipt = receipt_directory +
        "/invocation-" +
        sequence.val.to_string()
      sequence.val += 1
      // Write outside the product fixture before launching, so failed process
      // creation still identifies the exact requested registry coordinate.
      @fs.write_file(
        receipt + ".json",
        @testkit.canonical_json({
          "backend": Json("published-wasm"),
          "command": Json(invocation.command),
          "source_version": Json(coordinate),
          "program": Json(moonx),
          "args": Json(args),
          "cwd": Json(invocation.cwd),
          "stdin_bytes": Json(invocation.stdin.length()),
          "stdin_sha256": Json(@testkit.sha256_bytes(invocation.stdin)),
          "timeout_ms": Json(timeout_ms),
          "environment": @json.to_json(environment),
        }),
      )
      let run = candidate_executor(launch) catch {
        error => {
          @fs.write_file(receipt + ".launch-error.txt", error.to_string())
          fail(
            "candidate infrastructure process launch failed: " +
            error.to_string(),
          )
        }
      }
      let category = failure_category(run.output)
      {
        run,
        source_version: coordinate,
        program: moonx,
        args,
        infrastructure_error: if category == "asset_unavailable" ||
          category == "registry_transport" {
          Some(category)
        } else {
          None
        },
        retain_identity: true,
      }
    },
  }
}

///|
async fn run_network_release_scenario(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
  moonx : String,
  timeout_ms : Int32,
  oracle_image : String?,
  reports : Array[CaseReport],
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> Unit {
  guard @network_scenarios.supports(fixture.id) else {
    fail("unsupported published network scenario: " + fixture.id)
  }
  guard find_command(manifest, fixture.command) is Some(row) else {
    fail("missing network scenario release coordinate")
  }
  let coordinates : Array[String] = []
  for command in network_scenario_commands(fixture) {
    guard release_includes(manifest, command) else {
      fail("network scenario requires selected command: " + command)
    }
    guard find_command(manifest, command) is Some(command_row) else {
      fail("network scenario has no exact release coordinate: " + command)
    }
    coordinates.push(command_row.package_name + "@" + command_row.version)
  }
  let evidence = match report_root {
    Some(directory) => {
      @fs.mkdir(directory, recursive=true, allow_exist=true)
      let path = @path.Path(@fs.realpath(directory))
        .join(Path(report_directory_name(fixture.id)))
        .to_string()
      guard !@fs.exists(path) else {
        fail(
          "evidence already exists: " + path + "; choose a fresh --report-dir",
        )
      }
      @fs.mkdir(path)
      path
    }
    None => @fs.tmpdir(prefix="mooncmd-release-network-")
  }
  let work = evidence + "/work"
  let receipts = evidence + "/invocations"
  @fs.mkdir(work)
  @fs.mkdir(receipts)
  @fs.write_file(
    evidence + "/scenario-execution.json",
    @testkit.canonical_json({
      "id": Json(fixture.id),
      "backend": Json("published-wasm"),
      "moonx_coordinates": Json(coordinates),
      "oracle_image": @json.to_json(oracle_image),
      "verification": Json(
        if oracle_image is Some(_) {
          "differential"
        } else {
          "contract"
        },
      ),
    }),
  )
  let executor = published_network_executor(
    manifest,
    moonx,
    timeout_ms,
    receipts,
    candidate_executor~,
  )
  let failures : Array[String] = []
  let completed = @async.with_timeout_opt(
    fixture.timeout_ms.unwrap_or(
      if oracle_image is Some(_) {
        240000
      } else {
        120000
      },
    ),
    () => @network_scenarios.run(fixture.id, executor, work, oracle_image?),
  ) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("network scenario deadline expired; observations are partial")
  }
  reports.push({
    id: fixture.id,
    command: fixture.command,
    version: row.version,
    category: if completed is None {
      "timeout"
    } else if failures.any(failure => failure.contains("infrastructure")) {
      "runner_infra"
    } else if failures.is_empty() {
      "passed"
    } else {
      "candidate_failure"
    },
    detail: (if failures.is_empty() {
      "shared network assertions passed for " + coordinates.join(", ")
    } else {
      failures.join("; ")
    }) +
    "; artifacts: " +
    evidence,
  })
}
