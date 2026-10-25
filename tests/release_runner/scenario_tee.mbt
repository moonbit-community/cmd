///|
fn release_tee_scenario(fixture : ReleaseCase) -> Bool {
  fixture.command == "tee" &&
  (match (fixture.id, fixture.comparison) {
    ("tee-output-errors", Some("scenario"))
    | ("tee-default-pipe-boundary", Some("scenario"))
    | ("tee-output-errors-oracle", Some("oracle-scenario")) => true
    _ => false
  })
}

///|
fn published_tee_launch(
  manifest : ReleaseManifest,
  moonx : String,
  timeout_ms : Int32,
  work : String,
) -> CandidateInvocation raise {
  guard release_includes(manifest, "tee") &&
    find_command(manifest, "tee") is Some(row) else {
    fail("tee scenario requires the selected exact coordinate")
  }
  {
    program: moonx,
    args: [row.package_name + "@" + row.version, "--"],
    stdin: b"",
    cwd: work,
    environment: controlled_environment(Map([])),
    timeout_ms,
  }
}

///|
async fn run_tee_release_scenario(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
  moonx : String,
  timeout_ms : Int32,
  oracle_image : String?,
  reports : Array[CaseReport],
  report_root : String?,
) -> Unit {
  guard release_tee_scenario(fixture) else { fail("unknown tee scenario") }
  let evidence = match report_root {
    Some(directory) => {
      @fs.mkdir(directory, recursive=true, allow_exist=true)
      let path = @path.Path(@fs.realpath(directory))
        .join(Path(report_directory_name(fixture.id)))
        .to_string()
      @fs.mkdir(path)
      path
    }
    None => @fs.tmpdir(prefix="mooncmd-release-tee-")
  }
  let work = evidence + "/work"
  @fs.mkdir(work)
  let launch = published_tee_launch(manifest, moonx, timeout_ms, work)
  let row = find_command(manifest, "tee").unwrap()
  let failures : Array[String] = []
  let completed = @async.with_timeout_opt(timeout_ms, () => {
    @testkit.check_tee_modes(
      launch.program,
      launch.args,
      work,
      default_only=fixture.id == "tee-default-pipe-boundary",
    )
    if oracle_image is Some(image) {
      @testkit.check_tee_oracle(work + "/oracle", image)
    }
  }) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  reports.push({
    id: fixture.id,
    command: "tee",
    version: row.version,
    category: if completed is None {
      "timeout"
    } else if failures.any(text => text.contains("infrastructure")) {
      "runner_infra"
    } else if !failures.is_empty() {
      "candidate_failure"
    } else if fixture.id == "tee-default-pipe-boundary" {
      "boundary_passed"
    } else {
      "passed"
    },
    detail: (if failures.is_empty() {
      "closed-output status, diagnostics and later-sink effects passed"
    } else {
      failures.join("; ")
    }) +
    "; artifacts: " +
    evidence,
  })
}
