///|
fn release_mv_scenario(fixture : ReleaseCase) -> Bool {
  fixture.id == "mv-windows-wasm-links-boundary" &&
  fixture.command == "mv" &&
  fixture.comparison == Some("scenario") &&
  fixture.host_platforms == Some(["windows"])
}

///|
fn published_mv_launch(
  manifest : ReleaseManifest,
  moonx : String,
) -> @mv_scenarios.Launch raise {
  guard release_includes(manifest, "mv") &&
    find_command(manifest, "mv") is Some(row) else {
    fail("published mv scenario requires the selected exact mv coordinate")
  }
  let coordinate = row.package_name + "@" + row.version
  {
    program: moonx,
    prefix: [coordinate, "--"],
    source_version: coordinate,
    published: true,
  }
}

///|
async fn run_mv_release_scenario(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
  moonx : String,
  reports : Array[CaseReport],
  report_root : String?,
) -> Unit {
  guard release_mv_scenario(fixture) else {
    fail("unsupported published mv scenario")
  }
  let launch = published_mv_launch(manifest, moonx)
  let row = find_command(manifest, "mv").unwrap()
  let evidence = match report_root {
    Some(directory) => {
      @fs.mkdir(directory, recursive=true, allow_exist=true)
      let path = @path.Path(@fs.realpath(directory))
        .join(Path(report_directory_name(fixture.id)))
        .to_string()
      guard !@fs.exists(path) else { fail("evidence already exists: " + path) }
      @fs.mkdir(path)
      path
    }
    None => @fs.tmpdir(prefix="mooncmd-release-mv-")
  }
  let work = evidence + "/work"
  @fs.mkdir(work)
  let runtime = @testkit.run("moonrun", ["--version"], inherit_env=true)
  guard runtime.status == 0 && !runtime.stdout.is_empty() else {
    fail("infrastructure: cannot record the MoonX runtime version")
  }
  @fs.write_file(
    evidence + "/scenario-execution.json",
    @testkit.canonical_json({
      "id": fixture.id,
      "backend": "published-wasm",
      "source_version": launch.source_version,
      "moonrun": @utf8.decode(runtime.stdout),
    }),
  )
  let failures : Array[String] = []
  let completed = @async.with_timeout_opt(
    fixture.timeout_ms.unwrap_or(120000),
    () => @mv_scenarios.run(launch, true, work),
  ) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("mv scenario deadline expired; observations are partial")
  }
  reports.push({
    id: fixture.id,
    command: "mv",
    version: row.version,
    category: if completed is None {
      "timeout"
    } else if failures.is_empty() {
      "boundary_passed"
    } else if failures.any(value => value.contains("infrastructure")) {
      "runner_infra"
    } else {
      "candidate_failure"
    },
    detail: (if failures.is_empty() {
      "shared Windows link, referent and open-stdin assertions passed for " +
      launch.source_version
    } else {
      failures.join("; ")
    }) +
    "; artifacts: " +
    evidence,
  })
}
