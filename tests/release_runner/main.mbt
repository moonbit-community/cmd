///|
fn usage() -> String {
  "Usage: release-runner --manifest FILE [--suite differential|smoke|validate|all] " +
  "[--moonx PATH] [--docker PATH] [--oracle-image IMAGE] [--report-dir DIR] " +
  "[--command NAME] [--case ID] [--list] [--jobs N] [--timeout-ms N]"
}

///|
async fn read_release_manifest(path : String) -> ReleaseManifest raise Failure {
  @json.from_json(@json.parse(@fs.read_file(path).text())) catch {
    _ => fail("cannot read release manifest")
  }
}

///|
async fn read_base_manifest(path : String) -> BaseManifest raise Failure {
  let cases = @testkit.load_cases(path) catch {
    err => fail("cannot read base manifest: \{err}")
  }
  let source = @json.parse(@fs.read_file(path).text()) catch {
    _ => fail("cannot parse base manifest")
  }
  let schema = match source {
    { "schema": Number(number, ..), .. } => number.to_int()
    _ => 1
  }
  { schema, cases, }
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
  let included : Set[String] = Set::from_array(
    selected.map(fixture => fixture.id),
  )
  for id in manifest.case_ids {
    for fixture in all {
      if (fixture.id == id || fixture.aliases.unwrap_or([]).contains(id)) &&
        !included.contains(fixture.id) {
        selected.push(fixture)
        included.add(fixture.id)
      }
    }
  }
  selected
}

///|
fn filter_cases(
  fixtures : Array[ReleaseCase],
  commands : Array[String],
  ids : Array[String],
) -> Array[ReleaseCase] raise Failure {
  @testkit.select_cases(fixtures, commands, ids)
}

///|
fn has_contract_assertion(fixture : ReleaseCase) -> Bool {
  @testkit.contract_errors(fixture).is_empty()
}

///|
fn verification_level(fixture : ReleaseCase, differential : Bool) -> String {
  if fixture.expected_rejection is Some(_) ||
    fixture.comparison == Some("boundary") {
    "boundary"
  } else if fixture.comparison == Some("contract") {
    "contract"
  } else if differential {
    "differential"
  } else {
    "availability"
  }
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
fn host_platform() -> String {
  @testkit.host_platform()
}

///|
fn case_supported_on_host(fixture : ReleaseCase, platform : String) -> Bool {
  match fixture.host_platforms {
    Some(platforms) =>
      platforms.contains(platform) ||
      (platform != "windows" && platforms.contains("posix"))
    None => true
  }
}

///|
fn failure_category(result : @testkit.RunResult) -> String {
  let stderr = @utf8.decode(result.stderr) catch { _ => "" }
  if result.status == 255 &&
    stderr.contains("Prebuilt wasm asset does not exist") {
    "asset_unavailable"
  } else if result.status != 0 &&
    (
      stderr.contains("failed to read registry asset response") ||
      (
        (stderr.contains("mooncakes.io") || stderr.contains("registry")) &&
        contains_any(stderr, [
          "operation timed out", "timed out", "failed to connect", "could not resolve",
          "error sending request", "connection reset", "network is unreachable",
        ])
      )
    ) {
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
) -> @testkit.TimedRun {
  // MoonX consumes its first `--`. Supply the launcher's separator so a
  // command's own `--` remains part of its argv.
  let args = [row.package_name + "@" + row.version, "--"]
  args.append(expand_args(fixture.args, root, http_base?))
  let stdin = fixture.input(root~, http_base?)
  let environment = controlled_environment(fixture.environment)
  @testkit.run_with_deadline(
    moonx,
    args,
    timeout_ms,
    stdin~,
    cwd=fixture.working_directory(root),
    extra_env=environment,
    inherit_env=true,
  )
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
) -> @testkit.TimedRun {
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
    fixture.working_directory("/work"),
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
  args.append(expand_args(fixture.args, "/work", http_base?))
  let stdin = fixture.input(root="/work", http_base?)
  @testkit.run_with_deadline(docker, args, timeout_ms, stdin~, inherit_env=true)
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
  report_root : String?,
) -> Unit {
  let networked = is_network_case(fixture)
  let case_timeout_ms = fixture.timeout_ms.unwrap_or(timeout_ms)
  if fixture.comparison == Some("contract") && !has_contract_assertion(fixture) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "invalid_contract",
      detail: "contract needs a positive output assertion; status and forbidden internal diagnostics alone do not establish public behavior",
    })
    return
  }
  let policy_note = if row.policy_sensitive {
    " (policy-sensitive; authorization is checked by the separate policy suite)"
  } else {
    ""
  }
  let root = match report_root {
    Some(directory) => {
      if !@fs.exists(directory) {
        @fs.mkdir(directory, recursive=true)
      }
      let work = @path.Path(@fs.realpath(directory))
        .join(Path(fixture.id))
        .to_string()
      guard !@fs.exists(work) else {
        fail("evidence already exists: \{work}; choose a fresh --report-dir")
      }
      @fs.mkdir(work, recursive=true)
      work
    }
    None => @fs.tmpdir(prefix="mooncmd-release-\{fixture.id}-")
  }
  let reports_before = reports.length()
  defer @async.protect_from_cancel(() => {
    if reports.length() == reports_before {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "runner_infra",
        detail: "fixture or observation did not complete",
      })
    }
    if reports.any(report => {
        report.id == fixture.id && result_class(report.category) != "pass"
      }) {
      for report in reports {
        if report.id == fixture.id {
          report.detail += "; artifacts: " + root
        }
      }
    } else {
      @fs.rmdir(root, recursive=true) catch {
        err =>
          for report in reports {
            if report.id == fixture.id {
              report.category = "runner_infra"
              report.detail = "failed to clean fixture directory: \{err}; artifacts: " +
                root
            }
          }
      }
    }
  })
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  @fs.mkdir(candidate_root)
  prepare_fixture(candidate_root, fixture, http_base?)
  if differential &&
    fixture.comparison != Some("contract") &&
    fixture.expected_rejection is None {
    @fs.mkdir(oracle_root)
    prepare_fixture(oracle_root, fixture, http_base?)
  }
  let observed = @testkit.contract_observations(fixture)
  let before = if fixture.expected_rejection is Some(_) {
    snapshot(candidate_root, observe=observed[:], baseline=true)
  } else {
    []
  }
  let candidate_run = run_candidate(
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
  let candidate = candidate_run.output
  @fs.write_file(root + "/candidate.stdout", candidate.stdout)
  @fs.write_file(root + "/candidate.stderr", candidate.stderr)
  if candidate_run.timed_out {
    @fs.write_file(
      root + "/candidate.capture-incomplete",
      "Captured bytes are partial because the runner deadline expired.\n",
    )
  }
  if candidate_run.cleanup_error is Some(error) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "cleanup_failure",
      detail: error,
    })
    return
  }
  if candidate_run.timed_out {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "timeout",
      detail: "candidate did not finish before timeout",
    })
    return
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
  if fixture.expected_rejection is None {
    let errors = @testkit.check_contract(fixture, candidate, candidate_root)
    errors.append(@testkit.check_expected_files(fixture, candidate_root))
    if !errors.is_empty() {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: errors.join("; "),
      })
      return
    }
  }
  if fixture.expected_rejection is Some(reason) {
    if fixture.expected_status != 0 {
      let errors = @testkit.check_contract(fixture, candidate, candidate_root)
      errors.append(@testkit.check_expected_files(fixture, candidate_root))
      if !errors.is_empty() {
        reports.push({
          id: fixture.id,
          command: fixture.command,
          version: row.version,
          category: "semantic_mismatch",
          detail: errors.join("; "),
        })
        return
      }
    }
    if candidate.status == 0 ||
      (
        fixture.expected_status != 0 &&
        candidate.status != fixture.expected_status
      ) ||
      !@testkit.contains_bytes(candidate.stderr, reason) {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "semantic_mismatch",
        detail: "unsupported operation must report a nonzero status and the declared diagnostic: " +
        reason,
      })
    } else if !snapshots_equal(
        before,
        snapshot(candidate_root, observe=observed[:]),
      ) {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "unexpected_side_effect",
        detail: "rejected operation changed the required fixture observations",
      })
    } else {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "boundary_passed",
        detail: "unsupported operation rejected with preserved fixture: " +
        reason,
      })
    }
    return
  }
  if !differential && fixture.comparison != Some("contract") {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "availability_passed",
      detail: "versioned package invocation completed; no differential semantics claimed" +
      policy_note,
    })
    return
  }
  if fixture.comparison == Some("contract") {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "passed",
      detail: "published candidate contract passed" + policy_note,
    })
    return
  }
  let oracle_run = run_oracle(
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
  let oracle = oracle_run.output
  @fs.write_file(root + "/oracle.stdout", oracle.stdout)
  @fs.write_file(root + "/oracle.stderr", oracle.stderr)
  if oracle_run.timed_out {
    @fs.write_file(
      root + "/oracle.capture-incomplete",
      "Captured bytes are partial because the oracle deadline expired.\n",
    )
  }
  if oracle_run.cleanup_error is Some(error) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "cleanup_failure",
      detail: error,
    })
    return
  }
  if oracle_run.timed_out {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "oracle_failure",
      detail: "oracle did not finish before timeout",
    })
    return
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
  let candidate_files = snapshot(candidate_root, observe=observed[:])
  let oracle_files = snapshot(oracle_root, observe=observed[:])
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
  report_root : String?,
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
    docker_user, reports, report_root,
  ) catch {
    err =>
      if reports.any(report => report.id == fixture.id) {
        for report in reports {
          if report.id == fixture.id {
            report.detail += "; cause: \{err}"
          }
        }
      } else {
        reports.push({
          id: fixture.id,
          command: fixture.command,
          version: row.version,
          category: "runner_infra",
          detail: "fixture or observation failed: \{err}",
        })
      }
  }
}

///|
async fn detect_docker_user() -> String? {
  Some(@testkit.docker_user())
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
  timings : Map[String, Int64],
  jobs : Int,
  report_root : String?,
) -> Unit {
  let platform = host_platform()
  let slots = @async.Semaphore(jobs)
  @async.with_task_group <| group => {
    let tasks : Array[@async.Task[Array[CaseReport]]] = []
    for fixture in fixtures {
      tasks.push(
        group.spawn(() => {
          let reports : Array[CaseReport] = []
          slots.acquire()
          defer slots.release()
          let started = @async.now()
          defer {
            timings[fixture.id] = @async.now() - started
          }
          if !case_supported_on_host(fixture, platform) {
            let version = match find_command(manifest, fixture.command) {
              Some(row) => row.version
              None => ""
            }
            reports.push({
              id: fixture.id,
              command: fixture.command,
              version,
              category: "skipped_platform",
              detail: "case is not supported on host platform " + platform,
            })
            return reports
          }
          match find_command(manifest, fixture.command) {
            Some(row) =>
              run_case(
                moonx, docker, oracle_image, row, fixture, differential, timeout_ms,
                http_base, docker_user, reports, report_root,
              )
            None => ()
          }
          reports
        }),
      )
    }
    for task in tasks {
      reports.append(task.wait())
    }
  }
}

///|
async fn print_reports(
  reports : Array[CaseReport],
  fixtures : Array[ReleaseCase],
  differential : Bool,
) -> Unit {
  let mut failures = 0
  let mut semantic_passes = 0
  let mut availability_passes = 0
  let mut boundary_passes = 0
  let mut skipped = 0
  for report in reports {
    let result = result_class(report.category)
    let verification = report_verification(report, fixtures, differential)
    match result {
      "fail" | "infra" => failures += 1
      "skip" => skipped += 1
      "pass" if verification == "availability" => availability_passes += 1
      "pass" if verification == "boundary" => boundary_passes += 1
      "pass" if verification == "contract" || verification == "differential" =>
        semantic_passes += 1
      _ => ()
    }
    @stdio.stdout.write(
      "[\{result}/\{verification}/\{report.category}] \{report.command}@\{report.version} \{report.id}: \{report.detail}\n",
    )
  }
  @stdio.stdout.write(
    "Summary: \{semantic_passes} semantic, \{availability_passes} availability, \{boundary_passes} boundary, \{skipped} skipped, \{failures} failed.\n",
  )
  if failures > 0 {
    @stdio.stderr.write("\{failures} release runner case(s) failed\n")
    @sys.exit(1)
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
  let commands : Array[String] = []
  let ids : Array[String] = []
  let mut list_only = false
  let mut jobs = 4
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
        timeout_ms = @string.parse_int(args[index]) catch { _ => 0 }
      }
      "--jobs" if index + 1 < args.length() => {
        index += 1
        jobs = @string.parse_int(args[index]) catch { _ => 0 }
      }
      "--command" if index + 1 < args.length() => {
        index += 1
        commands.push(args[index])
      }
      "--case" if index + 1 < args.length() => {
        index += 1
        ids.push(args[index])
      }
      "--list" => list_only = true
      _ => {
        @stdio.stderr.write(usage() + "\n")
        @sys.exit(2)
        return
      }
    }
    index = index + 1
  }
  if timeout_ms <= 0 || jobs <= 0 {
    @stdio.stderr.write(
      "release-runner: timeout and jobs must be positive integers\n",
    )
    @sys.exit(2)
    return
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
  let manifest = read_release_manifest(manifest_path) catch {
    err => {
      @stdio.stderr.write(
        "release-runner: manifest infrastructure error: \{err}\n",
      )
      @sys.exit(1)
      return
    }
  }
  if manifest.candidate == Some(true) && suite != "validate" && !list_only {
    @stdio.stderr.write(
      "release-runner: unpublished candidates can only be validated; use local artifact probes until publication\n",
    )
    @sys.exit(2)
    return
  }
  let base_directory = if manifest.schema == 2 {
    @path.Path(@fs.realpath(manifest_path)).dirname()
  } else {
    @path.Path(@fs.realpath("."))
  }
  let base_path = base_directory.join(Path(manifest.base_manifest)).to_string()
  let base = read_base_manifest(base_path) catch {
    err => {
      @stdio.stderr.write("release-runner: case infrastructure error: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  let fixtures = filter_cases(selected_cases(manifest, base), commands, ids) catch {
    err => {
      @stdio.stderr.write("release-runner: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  // Published evidence is pinned by its manifest and remains replayable after
  // the working tree advances to a new candidate. Validate is the release-time
  // check that deliberately compares the manifest to local package versions.
  let validation = validate_release_manifest(manifest, base) +
    (if suite == "validate" {
      validate_package_versions(@fs.realpath("."), manifest)
    } else {
      []
    })
  if !validation.is_empty() {
    for failure in validation {
      @stdio.stderr.write("FAIL: \{failure}\n")
    }
    @sys.exit(1)
    return
  }
  if list_only {
    for fixture in fixtures {
      @stdio.stdout.write("\{fixture.command}\t\{fixture.id}\n")
    }
    return
  }
  if suite == "validate" {
    @stdio.stdout.write(
      "Release manifest valid: \{manifest.commands.length()} packages, \{fixtures.length()} selected cases.\n",
    )
    return
  }
  let reports : Array[CaseReport] = []
  if report_dir is Some(directory) && !@fs.exists(directory) {
    @fs.mkdir(directory, recursive=true)
  }
  let timings : Map[String, Int64] = Map([])
  let differential = suite == "differential" || suite == "all"
  let needs_oracle = differential &&
    fixtures.any(fixture => {
      case_supported_on_host(fixture, host_platform()) &&
      verification_level(fixture, true) == "differential"
    })
  let docker_user = if needs_oracle && !@platform.is_windows() {
    detect_docker_user() catch {
      _ => None
    }
  } else {
    None
  }
  if fixtures.any(fixture => {
      case_supported_on_host(fixture, host_platform()) &&
      is_network_case(fixture)
    }) {
    @async.with_task_group <| group => {
      let (server, reader, http_base) = spawn_http_fixture_process(group)
      group.add_defer(() => {
        reader.close()
        server.cancel()
        @async.protect_from_cancel(() => {
          ignore(server.wait()) catch {
            err =>
              reports.push({
                id: "http-fixture-cleanup",
                command: "fixture",
                version: "",
                category: "runner_infra",
                detail: "HTTP fixture wait failed during cleanup: \{err}",
              })
          }
        })
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
        timings,
        jobs,
        report_dir,
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
      timings,
      jobs,
      report_dir,
    )
  }
  match report_dir {
    Some(directory) =>
      write_report(directory, reports, fixtures, differential, timings)
    None => ()
  }
  print_reports(reports, fixtures, differential)
}
