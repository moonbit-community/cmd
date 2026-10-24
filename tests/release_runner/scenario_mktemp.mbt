///|
fn release_mktemp_scenario(fixture : ReleaseCase) -> Bool {
  fixture.command == "mktemp" &&
  (match (fixture.id, fixture.comparison) {
    ("mktemp-option-effects", Some("scenario"))
    | ("mktemp-option-effects-windows", Some("scenario"))
    | ("mktemp-option-effects-oracle", Some("oracle-scenario")) => true
    _ => false
  })
}

///|
async fn run_mktemp_release_scenario(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
  moonx : String,
  timeout_ms : Int32,
  oracle_image : String?,
  reports : Array[CaseReport],
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> Unit {
  guard release_mktemp_scenario(fixture) &&
    release_includes(manifest, "mktemp") &&
    find_command(manifest, "mktemp") is Some(row) else {
    fail("mktemp scenario requires the selected exact coordinate")
  }
  let evidence = match report_root {
    Some(directory) => {
      @fs.mkdir(directory, recursive=true, allow_exist=true)
      let path = @path.Path(@fs.realpath(directory))
        .join(Path(report_directory_name(fixture.id)))
        .to_string()
      @fs.mkdir(path)
      path
    }
    None => @fs.tmpdir(prefix="mooncmd-release-mktemp-")
  }
  let work = evidence + "/work"
  @fs.mkdir(work)
  let failures : Array[String] = []
  let coordinate = row.package_name + "@" + row.version
  let completed = @async.with_timeout_opt(timeout_ms, () => {
    @testkit.check_mktemp_options(
      work,
      (args, cwd, environment) => {
        let launch : CandidateInvocation = {
          program: moonx,
          args: [coordinate, "--", ..args],
          stdin: b"",
          cwd,
          environment: controlled_environment(environment),
          timeout_ms,
        }
        let name = @path.Path(cwd).basename().to_owned()
        @fs.write_file(
          evidence + "/" + name + ".launch.json",
          @testkit.canonical_json({
            "program": Json(moonx),
            "args": Json(launch.args),
            "cwd": Json(cwd),
            "environment": @json.to_json(launch.environment),
          }),
        )
        let run = candidate_executor(launch)
        @fs.write_file(evidence + "/" + name + ".stdout", run.output.stdout)
        @fs.write_file(evidence + "/" + name + ".stderr", run.output.stderr)
        @fs.write_file(
          evidence + "/" + name + ".status",
          run.output.status.to_string(),
        )
        guard !run.timed_out && run.cleanup_error is None else {
          fail("mktemp candidate lifecycle infrastructure failure")
        }
        run.output
      },
      check_mode=fixture.id != "mktemp-option-effects-windows",
    )
    if oracle_image is Some(image) {
      @testkit.check_mktemp_oracle(work + "/oracle", image)
    }
  }) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("mktemp scenario deadline expired")
  }
  reports.push({
    id: fixture.id,
    command: "mktemp",
    version: row.version,
    category: if completed is None {
      "timeout"
    } else if failures.any(text => text.contains("infrastructure")) {
      "runner_infra"
    } else if failures.is_empty() {
      "passed"
    } else {
      "candidate_failure"
    },
    detail: (if failures.is_empty() {
      "generated names and exclusive file/directory effects passed for " +
      coordinate
    } else {
      failures.join("; ")
    }) +
    "; artifacts: " +
    evidence,
  })
}
