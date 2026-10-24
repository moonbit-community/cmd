///|
fn release_diff_device_scenario(fixture : ReleaseCase) -> Bool {
  fixture.id == "diff-directory-devices-boundary" &&
  fixture.command == "diff" &&
  fixture.comparison == Some("scenario") &&
  fixture.host_platforms == Some(["linux", "macos"])
}

///|
fn published_diff_device_launch(
  manifest : ReleaseManifest,
  moonx : String,
  timeout_ms : Int32,
  work : String,
) -> CandidateInvocation raise {
  guard release_includes(manifest, "diff") &&
    find_command(manifest, "diff") is Some(row) else {
    fail("published diff scenario requires the selected exact diff coordinate")
  }
  {
    program: moonx,
    args: [row.package_name + "@" + row.version, "--", "-r", "left", "right"],
    timeout_ms,
    stdin: b"",
    cwd: work,
    environment: controlled_environment(Map([])),
  }
}

///|
async fn run_diff_device_release_scenario(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
  moonx : String,
  timeout_ms : Int32,
  reports : Array[CaseReport],
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> Unit {
  guard release_diff_device_scenario(fixture) else {
    fail("unsupported published diff scenario")
  }
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
    None => @fs.tmpdir(prefix="mooncmd-release-diff-")
  }
  let work = evidence + "/work"
  @fs.mkdir(work)
  let launch = published_diff_device_launch(manifest, moonx, timeout_ms, work)
  let row = find_command(manifest, "diff").unwrap()
  @fs.write_file(
    evidence + "/scenario-execution.json",
    @testkit.canonical_json({
      "id": Json(fixture.id),
      "backend": "published-wasm",
      "source_version": Json(row.package_name + "@" + row.version),
      "program": Json(launch.program),
      "args": Json(launch.args),
    }),
  )
  let failures : Array[String] = []
  let timed_out = Ref(false)
  let completed = @async.with_timeout_opt(
    fixture.timeout_ms.unwrap_or(timeout_ms),
    () => {
      @fs.mkdir(work + "/left")
      @fs.mkdir(work + "/right")
      @fs.symlink(work + "/left/device", target="/dev/null")
      defer @async.protect_from_cancel(() => @fs.remove(work + "/left/device"))
      @fs.symlink(work + "/right/device", target="/dev/zero")
      defer @async.protect_from_cancel(() => @fs.remove(work + "/right/device"))
      assert_eq(@fs.kind(work + "/left/device"), CharDevice)
      assert_eq(@fs.kind(work + "/right/device"), CharDevice)
      let run = candidate_executor(launch)
      @fs.write_file(evidence + "/stdout.bin", run.output.stdout)
      @fs.write_file(evidence + "/stderr.bin", run.output.stderr)
      @fs.write_file(evidence + "/status.txt", run.output.status.to_string())
      if run.cleanup_error is Some(error) {
        fail("cleanup infrastructure: " + error)
      }
      if run.timed_out {
        timed_out.val = true
        fail("diff scenario command deadline expired")
      }
      let category = failure_category(run.output)
      if category == "asset_unavailable" || category == "registry_transport" {
        fail("candidate infrastructure: " + category)
      }
      let left_kind = @fs.kind(work + "/left/device", follow_symlink=false)
      let right_kind = @fs.kind(work + "/right/device", follow_symlink=false)
      let left_target = @fs.realpath(work + "/left/device")
      let right_target = @fs.realpath(work + "/right/device")
      @fs.write_file(
        work + "/device-observations.json",
        @testkit.canonical_json({
          "left": {
            "kind": Json(if left_kind == SymLink { "symlink" } else { "other" }),
            "resolved_target": Json(left_target),
          },
          "right": {
            "kind": Json(
              if right_kind == SymLink {
                "symlink"
              } else {
                "other"
              },
            ),
            "resolved_target": Json(right_target),
          },
        }),
      )
      assert_eq(run.output.status, 2)
      assert_eq(run.output.stdout, b"")
      assert_eq(
        run.output.stderr,
        b"diff: unsupported capability: directory device-number comparison\n",
      )
      assert_eq(left_kind, SymLink)
      assert_eq(right_kind, SymLink)
      assert_eq(left_target, "/dev/null")
      assert_eq(right_target, "/dev/zero")
    },
  ) catch {
    error => {
      failures.push(error.to_string())
      Some(())
    }
  }
  if completed is None {
    failures.push("diff scenario deadline expired; observations are partial")
  }
  reports.push({
    id: fixture.id,
    command: "diff",
    version: row.version,
    category: if completed is None || timed_out.val {
      "timeout"
    } else if failures.is_empty() {
      "boundary_passed"
    } else if failures.any(value => value.contains("infrastructure")) {
      "runner_infra"
    } else {
      "candidate_failure"
    },
    detail: (if failures.is_empty() {
      "device-number rejection and unchanged links passed for " +
      row.package_name +
      "@" +
      row.version
    } else {
      failures.join("; ")
    }) +
    "; artifacts: " +
    evidence,
  })
}
