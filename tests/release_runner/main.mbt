///|
fn usage() -> String {
  "Usage: release-runner --manifest FILE [--suite differential|smoke|validate|all] " +
  "[--moonx PATH] [--docker PATH] [--oracle-image IMAGE] [--report-dir DIR]"
}

///|
async fn read_release_manifest(path : String) -> ReleaseManifest raise Failure {
  @json.from_json(@json.parse(@fs.read_file(path).text())) catch {
    _ => fail("cannot read release manifest")
  }
}

///|
async fn read_base_manifest(path : String) -> BaseManifest raise Failure {
  @json.from_json(@json.parse(@fs.read_file(path).text())) catch {
    _ => fail("cannot read base manifest")
  }
}

///|
fn find_command(
  manifest : ReleaseManifest,
  command : String,
) -> ReleaseCommand? {
  for row in manifest.commands {
    if row.name == command {
      return Some(row)
    }
  }
  None
}

///|
fn selected_cases(
  manifest : ReleaseManifest,
  base : BaseManifest,
) -> Array[ReleaseCase] {
  let all = base.cases + manifest.extra_cases
  if manifest.case_ids.is_empty() {
    return all
  }
  let selected : Array[ReleaseCase] = manifest.extra_cases.copy()
  for id in manifest.case_ids {
    for fixture in all {
      if fixture.id == id {
        selected.push(fixture)
      }
    }
  }
  selected
}

///|
fn contains_any(text : String, needles : Array[String]) -> Bool {
  for needle in needles {
    if text.contains(needle) {
      return true
    }
  }
  false
}

///|
fn ends_with_newline(data : Bytes) -> Bool {
  data.length() > 0 &&
  data[data.length() - 1] == b'\n' &&
  (data.length() == 1 || data[data.length() - 2] != b'\n')
}

///|
fn failure_category(result : @testkit.RunResult) -> String {
  let stderr = @utf8.decode(result.stderr) catch { _ => "" }
  if result.status == 255 &&
    stderr.contains("Prebuilt wasm asset does not exist") {
    "asset_unavailable"
  } else if contains_any(stderr, [
      "operation timed out", "timed out", "failed to connect", "could not resolve",
      "failed to read registry asset response", "error sending request", "connection reset",
      "network is unreachable",
    ]) {
    "registry_transport"
  } else {
    "candidate_failure"
  }
}

///|
fn first_difference(left : Bytes, right : Bytes) -> String {
  let shared = left.length().min(right.length())
  for index = 0; index < shared; index = index + 1 {
    if left[index] != right[index] {
      return "byte \{index}: candidate=\{left[index]} oracle=\{right[index]}"
    }
  }
  if left.length() != right.length() {
    "length: candidate=\{left.length()} oracle=\{right.length()}"
  } else {
    "no byte difference"
  }
}

///|
async fn run_candidate(
  moonx : String,
  row : ReleaseCommand,
  fixture : ReleaseCase,
  root : String,
  http_base : String?,
  timeout_ms : Int,
) -> (@testkit.RunResult, String?) {
  let args = [row.package_name + "@" + row.version]
  args.append(expand_args(fixture.args, root, http_base?))
  let stdin = decode_hex(fixture.stdin_hex, fixture.id + " stdin")
  let environment = controlled_environment(fixture.environment)
  for attempt in 0..<2 {
    let result = @async.with_timeout_opt(timeout_ms, () => {
      @testkit.run(
        moonx,
        args,
        stdin~,
        cwd=root,
        extra_env=environment,
        inherit_env=true,
      )
    })
    match result {
      Some(result) => {
        if attempt == 0 && failure_category(result) == "registry_transport" {
          continue
        }
        return (result, None)
      }
      None =>
        return ({ status: 124, stdout: b"", stderr: b"", }, Some("timeout"))
    }
  }
  abort("unreachable")
}

///|
async fn run_oracle(
  docker : String,
  image : String,
  fixture : ReleaseCase,
  root : String,
  http_base : String?,
  networked : Bool,
  docker_user : String?,
  timeout_ms : Int,
) -> (@testkit.RunResult, String?) {
  let args = ["run", "--rm", "-i"]
  match docker_user {
    Some(value) => args.append(["--user", value])
    None => ()
  }
  args.append([
    "--network",
    if networked {
      "host"
    } else {
      "none"
    },
    "--read-only",
    "--tmpfs",
    "/tmp:rw,nosuid,nodev,size=64m",
    "-v",
    root + ":/work:rw",
    "-w",
    "/work",
    "-e",
    "LC_ALL=C",
    "-e",
    "LANG=C",
    "-e",
    "TZ=UTC",
  ])
  for name, value in fixture.environment {
    if name != "PATH" && name != "LC_ALL" && name != "LANG" && name != "TZ" {
      args.push("-e")
      args.push(name + "=" + value)
    }
  }
  args.append(["-e", "PATH=/oracle/bin", image, fixture.command])
  args.append(expand_args(fixture.args, root, http_base?))
  let stdin = decode_hex(fixture.stdin_hex, fixture.id + " stdin")
  let result = @async.with_timeout_opt(timeout_ms, () => {
    @testkit.run(docker, args, stdin~, inherit_env=true)
  })
  match result {
    Some(result) => (result, None)
    None => ({ status: 124, stdout: b"", stderr: b"", }, Some("timeout"))
  }
}

///|
async fn run_case_inner(
  moonx : String,
  docker : String,
  oracle_image : String,
  row : ReleaseCommand,
  fixture : ReleaseCase,
  differential : Bool,
  timeout_ms : Int,
  http_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
) -> Unit {
  let networked = is_network_case(fixture)
  let case_timeout_ms = fixture.timeout_ms.unwrap_or(timeout_ms)
  let policy_note = if row.policy_sensitive {
    " (policy-sensitive; authorization is checked by the separate policy suite)"
  } else {
    ""
  }
  let root = @fs.tmpdir(prefix="mooncmd-release-\{fixture.id}-")
  defer (@fs.rmdir(root, recursive=true) catch {
    err =>
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "runner_infra",
        detail: "failed to clean fixture directory: \{err}",
      })
  })
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  @fs.mkdir(candidate_root)
  @fs.mkdir(oracle_root)
  prepare_fixture(candidate_root, fixture, http_base?)
  prepare_fixture(oracle_root, fixture, http_base?)
  let candidate_before = snapshot(candidate_root)
  let (candidate, candidate_timeout) = run_candidate(
    moonx, row, fixture, candidate_root, http_base, case_timeout_ms,
  ) catch {
    err => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "runner_infra",
        detail: "candidate could not start: \{err}",
      })
      return
    }
  }
  match candidate_timeout {
    Some(category) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category,
        detail: "candidate did not finish before timeout",
      })
      return
    }
    None => ()
  }
  let candidate_category = failure_category(candidate)
  if candidate_category == "asset_unavailable" {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: candidate_category,
      detail: @utf8.decode(candidate.stderr) catch {
        _ => ""
      },
    })
    return
  }
  if candidate_category == "registry_transport" {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: candidate_category,
      detail: @utf8.decode(candidate.stderr) catch {
        _ => ""
      },
    })
    return
  }
  if candidate.status != fixture.expected_status {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "candidate_failure",
      detail: "expected status \{fixture.expected_status}, got \{candidate.status}",
    })
    return
  }
  if candidate.status != 0 {
    let candidate_after = snapshot(candidate_root)
    if !snapshots_equal(candidate_before, candidate_after) {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "unexpected_side_effect",
        detail: "failed candidate changed its fixture directory",
      })
      return
    }
  }
  match fixture.expected_stdout_contains {
    Some(needle) if !@testkit.contains_bytes(candidate.stdout, needle) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stdout missing '\{needle}'",
      })
      return
    }
    _ => ()
  }
  match fixture.expected_stdout_ends_with_newline {
    Some(true) if !ends_with_newline(candidate.stdout) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stdout must end with a newline",
      })
      return
    }
    Some(false) if ends_with_newline(candidate.stdout) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stdout must not end with a newline",
      })
      return
    }
    _ => ()
  }
  match fixture.expected_stderr_ends_with_newline {
    Some(true) if !ends_with_newline(candidate.stderr) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stderr must end with a newline",
      })
      return
    }
    Some(false) if ends_with_newline(candidate.stderr) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stderr must not end with a newline",
      })
      return
    }
    _ => ()
  }
  match fixture.forbidden_stderr {
    Some(needles) if contains_any(
        @utf8.decode(candidate.stderr) catch {
          _ => ""
        },
        needles,
      ) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "stderr contains a forbidden internal diagnostic",
      })
      return
    }
    _ => ()
  }
  if !differential || fixture.comparison == Some("contract") {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "passed",
      detail: "published candidate contract passed" + policy_note,
    })
    return
  }
  let (oracle, oracle_timeout) = run_oracle(
    docker, oracle_image, fixture, oracle_root, http_base, networked, docker_user,
    case_timeout_ms,
  ) catch {
    err => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "oracle_failure",
        detail: "oracle could not start: \{err}",
      })
      return
    }
  }
  match oracle_timeout {
    Some(_) => {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "oracle_failure",
        detail: "oracle did not finish before timeout",
      })
      return
    }
    None => ()
  }
  if oracle.status != fixture.expected_status {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "oracle_failure",
      detail: "oracle expected status \{fixture.expected_status}, got \{oracle.status}",
    })
    return
  }
  let candidate_stdout = normalize_text(
    candidate.stdout,
    "stdout",
    fixture.normalizations,
    candidate_root,
  )
  let oracle_stdout = normalize_text(
    oracle.stdout,
    "stdout",
    fixture.normalizations,
    oracle_root,
  )
  let candidate_stderr = normalize_text(
    candidate.stderr,
    "stderr",
    fixture.normalizations,
    candidate_root,
  )
  let oracle_stderr = normalize_text(
    oracle.stderr,
    "stderr",
    fixture.normalizations,
    oracle_root,
  )
  if !@testkit.bytes_equal(candidate_stdout, oracle_stdout) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "semantic_mismatch",
      detail: "stdout " + first_difference(candidate_stdout, oracle_stdout),
    })
    return
  }
  if !@testkit.bytes_equal(candidate_stderr, oracle_stderr) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "semantic_mismatch",
      detail: "stderr " + first_difference(candidate_stderr, oracle_stderr),
    })
    return
  }
  let candidate_files = snapshot(candidate_root)
  let oracle_files = snapshot(oracle_root)
  if !snapshots_equal(candidate_files, oracle_files) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "unexpected_side_effect",
      detail: "filesystem snapshots differ",
    })
    return
  }
  reports.push({
    id: fixture.id,
    command: fixture.command,
    version: row.version,
    category: "passed",
    detail: "candidate and pinned oracle agree" + policy_note,
  })
}

///|
async fn run_case(
  moonx : String,
  docker : String,
  oracle_image : String,
  row : ReleaseCommand,
  fixture : ReleaseCase,
  differential : Bool,
  timeout_ms : Int,
  http_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
) -> Unit {
  if is_network_case(fixture) && http_base is None {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "runner_infra",
      detail: "loopback HTTP fixture is unavailable",
    })
    return
  }
  run_case_inner(
    moonx, docker, oracle_image, row, fixture, differential, timeout_ms, http_base,
    docker_user, reports,
  )
}

///|
async fn detect_docker_user() -> String? {
  let uid = @testkit.run("id", ["-u"], stdin=b"")
  let gid = @testkit.run("id", ["-g"], stdin=b"")
  if uid.status == 0 && gid.status == 0 {
    let uid_text = (@utf8.decode(uid.stdout) catch { _ => "" })
      .trim()
      .to_owned()
    let gid_text = (@utf8.decode(gid.stdout) catch { _ => "" })
      .trim()
      .to_owned()
    if !uid_text.is_empty() && !gid_text.is_empty() {
      return Some(uid_text + ":" + gid_text)
    }
  }
  None
}

///|
async fn run_selected_cases(
  manifest : ReleaseManifest,
  fixtures : Array[ReleaseCase],
  moonx : String,
  docker : String,
  oracle_image : String,
  differential : Bool,
  timeout_ms : Int,
  http_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
) -> Unit {
  for fixture in fixtures {
    match find_command(manifest, fixture.command) {
      Some(row) =>
        run_case(
          moonx, docker, oracle_image, row, fixture, differential, timeout_ms, http_base,
          docker_user, reports,
        )
      None => ()
    }
  }
}

///|
async fn print_reports(reports : Array[CaseReport]) -> Unit {
  let mut failures = 0
  for report in reports {
    if report.category != "passed" {
      failures = failures + 1
    }
    @stdio.stdout.write(
      "[\{report.category}] \{report.command}@\{report.version} \{report.id}: \{report.detail}\n",
    )
  }
  if failures > 0 {
    @stdio.stderr.write("\{failures} release runner case(s) failed\n")
    @sys.exit(1)
  }
}

///|
async fn main {
  let raw_args = @env.args()
  if raw_args.length() == 2 && raw_args[1] == "--http-fixture-server" {
    run_http_fixture_process()
    return
  }
  let args = raw_args[1:]
  let mut manifest_path : String? = None
  let mut suite = "differential"
  let mut moonx = "moonx"
  let mut docker = "docker"
  let mut oracle_image = "mooncmd-oracle:phase0"
  let mut report_dir : String? = None
  let mut timeout_ms = 120000
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--manifest" if index + 1 < args.length() => {
        index = index + 1
        manifest_path = Some(args[index])
      }
      "--suite" if index + 1 < args.length() => {
        index = index + 1
        suite = args[index]
      }
      "--moonx" if index + 1 < args.length() => {
        index = index + 1
        moonx = args[index]
      }
      "--docker" if index + 1 < args.length() => {
        index = index + 1
        docker = args[index]
      }
      "--oracle-image" if index + 1 < args.length() => {
        index = index + 1
        oracle_image = args[index]
      }
      "--report-dir" if index + 1 < args.length() => {
        index = index + 1
        report_dir = Some(args[index])
      }
      "--timeout-ms" if index + 1 < args.length() => {
        index = index + 1
        timeout_ms = @string.parse_int(args[index]) catch { _ => 120000 }
      }
      _ => {
        @stdio.stderr.write(usage() + "\n")
        @sys.exit(2)
        return
      }
    }
    index = index + 1
  }
  guard manifest_path is Some(manifest_path) else {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  if suite != "differential" &&
    suite != "smoke" &&
    suite != "validate" &&
    suite != "all" {
    @stdio.stderr.write("release-runner: invalid suite '\{suite}'\n")
    @sys.exit(2)
    return
  }
  let manifest = read_release_manifest(manifest_path)
  let base_path = @path.Path(@fs.realpath("."))
    .join(Path(manifest.base_manifest))
    .to_string()
  let base = read_base_manifest(base_path)
  let validation = validate_release_manifest(manifest, base) +
    validate_package_versions(@fs.realpath("."), manifest)
  if !validation.is_empty() {
    for failure in validation {
      @stdio.stderr.write("FAIL: \{failure}\n")
    }
    @sys.exit(1)
    return
  }
  if suite == "validate" {
    @stdio.stdout.write(
      "Release manifest valid: \{manifest.commands.length()} packages, \{selected_cases(manifest, base).length()} cases.\n",
    )
    return
  }
  let reports : Array[CaseReport] = []
  let fixtures = selected_cases(manifest, base)
  let differential = suite == "differential" || suite == "all"
  let docker_user = if differential { detect_docker_user() } else { None }
  if fixtures.any(is_network_case) {
    @async.with_task_group <| group => {
      let (server, reader, http_base) = spawn_http_fixture_process(group)
      group.add_defer(() => {
        reader.close()
        server.cancel()
        ignore(server.wait()) catch {
          _ => ()
        }
      })
      run_selected_cases(
        manifest,
        fixtures,
        moonx,
        docker,
        oracle_image,
        differential,
        timeout_ms,
        Some(http_base),
        docker_user,
        reports,
      )
    }
  } else {
    run_selected_cases(
      manifest,
      fixtures,
      moonx,
      docker,
      oracle_image,
      differential,
      timeout_ms,
      None,
      docker_user,
      reports,
    )
  }
  match report_dir {
    Some(directory) => write_report(directory, reports)
    None => ()
  }
  print_reports(reports)
}
