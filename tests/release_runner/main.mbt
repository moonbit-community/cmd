///|
fn usage() -> String {
  "Usage: release-runner --manifest FILE [--suite differential|smoke|validate|all] " +
  "[--moonx PATH] [--docker PATH] [--oracle-image IMAGE] [--oracle-profile FILE] [--report-dir DIR] " +
  "[--command NAME] [--case ID] [--list] [--jobs N] [--timeout-ms N] [--historical-replay]\n" +
  "       release-runner --generate-candidate [--template FILE] [--metadata FILE] " +
  "[--registry FILE] [--active-output FILE] [--output FILE]\n" +
  "       release-runner --manifest FILE --verify-candidate --freeze-evidence FILE [run options]\n" +
  "       release-runner --manifest FILE --freeze-published --freeze-evidence FILE --release-id ID\n" +
  "       release-runner --seal-oracle sha256:IMAGE-ID [--oracle-profile FILE]"
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
  } else if differential && fixture.oracle == Some(true) {
    "differential"
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
fn report_directory_name(id : String) -> String {
  let digits = "0123456789abcdef"
  let suffix = StringBuilder()
  for character in id {
    let code = character.to_int()
    suffix.write_char(digits[code >> 4].unsafe_to_char())
    suffix.write_char(digits[code & 0xF].unsafe_to_char())
  }
  id + "-" + suffix.to_string()
}

///|
fn host_platform() -> String {
  @testkit.host_platform()
}

///|
fn case_supported_on_host(fixture : ReleaseCase, platform : String) -> Bool {
  if platform == "windows" &&
    fixture.args.any(arg => arg.contains("${HTTPS_BASE}")) {
    return false
  }
  match fixture.host_platforms {
    Some(platforms) =>
      platforms.contains(platform) ||
      (platform != "windows" && platforms.contains("posix"))
    None => true
  }
}

///|
fn requires_serial_fixture(fixture : ReleaseCase) -> Bool {
  fixture.delay_ms.unwrap_or(0) > 0 ||
  fixture.files.any(file => file.atime is Some(_) || file.mtime is Some(_)) ||
  fixture.observe
  .unwrap_or([])
  .any(dimension => {
    dimension == "atime" || dimension == "mtime" || dimension == "ctime"
  })
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
fn expand_network_args(
  args : ArrayView[String],
  http_base : String?,
  https_base : String?,
) -> Array[String] {
  args.map(arg => {
    let with_http = match http_base {
      Some(base) => arg.replace_all(old="${HTTP_BASE}", new=base)
      None => arg
    }
    match https_base {
      Some(base) => with_http.replace_all(old="${HTTPS_BASE}", new=base)
      None => with_http
    }
  })
}

///|
async fn run_candidate(
  moonx : String,
  row : ReleaseCommand,
  fixture : ReleaseCase,
  root : String,
  http_base : String?,
  https_base : String?,
  timeout_ms : Int32,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> @testkit.TimedRun {
  // MoonX consumes its first `--`. Supply the launcher's separator so a
  // command's own `--` remains part of its argv.
  let args = [row.package_name + "@" + row.version, "--"]
  args.append(
    expand_args(
      expand_network_args(fixture.args, http_base, https_base),
      root,
      http_base?,
    ),
  )
  let stdin = fixture.input(root~, http_base?)
  let environment = controlled_environment(
    @testkit.expand_environment(fixture.environment, root, http_base?),
  )
  candidate_executor({
    program: moonx,
    args,
    timeout_ms,
    stdin,
    cwd: fixture.working_directory(root),
    environment,
  })
}

///|
async fn run_oracle(
  docker : String,
  image : String,
  fixture : ReleaseCase,
  root : String,
  http_base : String?,
  https_base : String?,
  networked : Bool,
  docker_user : String?,
  timeout_ms : Int32,
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
  let environment = @testkit.expand_environment(
    fixture.environment,
    "/work",
    http_base?,
  )
  for name, value in environment {
    if name != "PATH" {
      args.push("-e")
      args.push(name + "=" + value)
    }
  }
  args.append(["-e", "PATH=/oracle/bin", image, fixture.command])
  args.append(
    expand_args(
      expand_network_args(fixture.args, http_base, https_base),
      "/work",
      http_base?,
    ),
  )
  let stdin = fixture.input(root="/work", http_base?)
  @testkit.record_execution_environment(
    fixture.command,
    extra_env=controlled_environment(environment),
    inherit_env=false,
  )
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
  timeout_ms : Int32,
  http_base : String?,
  https_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
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
        .join(Path(report_directory_name(fixture.id)))
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
  let compare_oracle = verification_level(fixture, differential) ==
    "differential"
  if compare_oracle {
    @fs.mkdir(oracle_root)
    prepare_fixture(oracle_root, fixture, http_base?)
  }
  let observed = @testkit.contract_observations(fixture)
  let before = if fixture.expected_rejection is Some(_) {
    snapshot(
      candidate_root,
      observe=observed[:],
      baseline=true,
      preserve_identity=true,
    )
  } else {
    []
  }
  let candidate_run = run_candidate(
    moonx,
    row,
    fixture,
    candidate_root,
    http_base,
    https_base,
    case_timeout_ms,
    candidate_executor~,
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
        snapshot(candidate_root, observe=observed[:], preserve_identity=true),
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
  if fixture.comparison == Some("contract") && !compare_oracle {
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
    docker, oracle_image, fixture, oracle_root, http_base, https_base, networked,
    docker_user, case_timeout_ms,
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
  if fixture.comparison == Some("contract") {
    let errors = @testkit.check_contract(fixture, oracle, oracle_root)
    errors.append(@testkit.check_expected_files(fixture, oracle_root))
    if !errors.is_empty() {
      reports.push({
        id: fixture.id,
        command: fixture.command,
        version: row.version,
        category: "oracle_failure",
        detail: "pinned oracle violates contract: " + errors.join("; "),
      })
      return
    }
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
  let stderr_matches = match fixture.expected_stderr_contains {
    Some(reason) if fixture.diagnostic_reason is Some(_) =>
      @testkit.contains_bytes(candidate_stderr, reason) &&
      @testkit.contains_bytes(oracle_stderr, reason)
    _ => @testkit.bytes_equal(candidate_stderr, oracle_stderr)
  }
  if !stderr_matches {
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
  timeout_ms : Int32,
  http_base : String?,
  https_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> Unit {
  let needs_http = is_network_case(fixture)
  let needs_https = fixture.args.any(arg => arg.contains("${HTTPS_BASE}"))
  if (needs_http && http_base is None) || (needs_https && https_base is None) {
    reports.push({
      id: fixture.id,
      command: fixture.command,
      version: row.version,
      category: "runner_infra",
      detail: "required loopback HTTP or HTTPS fixture is unavailable",
    })
    return
  }
  run_case_inner(
    moonx,
    docker,
    oracle_image,
    row,
    fixture,
    differential,
    timeout_ms,
    http_base,
    https_base,
    docker_user,
    reports,
    report_root,
    candidate_executor~,
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
  suite : String,
  timeout_ms : Int32,
  http_base : String?,
  https_base : String?,
  docker_user : String?,
  reports : Array[CaseReport],
  timings : Map[String, Int64],
  jobs : Int32,
  report_root : String?,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
) -> Unit {
  let differential = suite == "differential" || suite == "all"
  // Published smoke retains serial process ownership even when callers ask
  // for more jobs. Keep this rule in the execution path, not only CLI parsing.
  let jobs = if suite == "smoke" { 1 } else { jobs }
  if jobs > 1 && fixtures.any(requires_serial_fixture) {
    run_selected_cases(
      manifest,
      fixtures.filter(fixture => !requires_serial_fixture(fixture)),
      moonx,
      docker,
      oracle_image,
      suite,
      timeout_ms,
      http_base,
      https_base,
      docker_user,
      reports,
      timings,
      jobs,
      report_root,
      candidate_executor~,
    )
    run_selected_cases(
      manifest,
      fixtures.filter(requires_serial_fixture),
      moonx,
      docker,
      oracle_image,
      suite,
      timeout_ms,
      http_base,
      https_base,
      docker_user,
      reports,
      timings,
      1,
      report_root,
      candidate_executor~,
    )
    return
  }
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
              detail: if platform == "windows" &&
                fixture.args.any(arg => arg.contains("${HTTPS_BASE}")) {
                "fixed OpenSSL TLS fixture is not provisioned on Windows"
              } else {
                "case is not supported on host platform " + platform
              },
            })
            return reports
          }
          match find_command(manifest, fixture.command) {
            Some(row) =>
              run_case(
                moonx,
                docker,
                oracle_image,
                row,
                fixture,
                differential,
                timeout_ms,
                http_base,
                https_base,
                docker_user,
                reports,
                report_root,
                candidate_executor~,
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
/// Resolve frozen manifests after published files were moved under the
/// historical directory. A freeze-created resolved sidecar takes precedence;
/// otherwise the direct path and then basename fallback keep legacy schema-1
/// manifests byte-identical without rewriting their recorded paths.
async fn resolve_base_manifest(
  base_directory : String,
  base_manifest : String,
  manifest_path? : String,
) -> String {
  // Newly archived manifests keep their original bytes and carry a separate
  // resolved corpus, so replay never follows the current mutable case files.
  if manifest_path is Some(path) {
    let frozen_cases = path + ".cases.json"
    if @fs.exists(frozen_cases) {
      return frozen_cases
    }
  }
  let direct = @path.Path(base_directory).join(Path(base_manifest)).to_string()
  let direct_exists = @fs.exists(direct) catch { _ => false }
  if direct_exists {
    return direct
  }
  let root = workspace_root() catch { _ => @fs.realpath(".") }
  let release_root = @path.Path(root)
    .join(Path("tests/release_runner"))
    .to_string()
  let historical = @path.Path(release_root)
    .join(Path("historical"))
    .join(Path(@path.Path(base_manifest).basename().to_owned()))
    .to_string()
  let historical_exists = @fs.exists(historical) catch { _ => false }
  if historical_exists {
    return historical
  }
  direct
}

///|
/// Find the module root when Moon runs this package's tests from the package
/// directory.  The release CLI normally starts at the root, but test runners
/// may use `tests/release_runner` as their working directory.
async fn workspace_root() -> String {
  let candidates = [".", "..", "../..", "../../..", "../../../.."]
  for candidate in candidates {
    if (@fs.exists(candidate + "/commands") catch { _ => false }) &&
      (@fs.exists(candidate + "/tests") catch { _ => false }) {
      return @fs.realpath(candidate)
    }
  }
  fail("cannot locate cmd workspace root")
}

///|
async fn workspace_input(root : String, configured : String) -> String {
  let configured_path = @path.Path(configured)
  if configured_path.is_absolute() ||
    (@fs.exists(configured) catch { _ => false }) {
    configured
  } else {
    @path.Path(root).join(configured_path).to_string()
  }
}

///|
async fn run_driver() -> Unit {
  @testkit.begin_environment_capture()
  let raw_args = @env.args()
  if raw_args.length() == 2 && raw_args[1] == "--http-fixture-server" {
    run_http_fixture_process()
    return
  }
  let oracle_options = @testkit.parse_oracle_options(raw_args[1:]) catch {
    error => {
      @stdio.stderr.write(error.to_string() + "\n" + usage() + "\n")
      @sys.exit(2)
      return
    }
  }
  let args = oracle_options.arguments[:]
  let oracle_profile_path = oracle_options.profile_path
  if oracle_options.seal_digest is Some(digest) {
    @testkit.seal_oracle_profile(
      oracle_profile_path,
      digest,
      expected_profile_path="tests/runner/image/profile.json",
    )
    return
  }
  let mut manifest_path : String? = None
  let mut suite = "differential"
  let mut moonx = "moonx"
  let mut docker = "docker"
  let mut oracle_image = "mooncmd-oracle:phase0"
  let mut report_dir : String? = Some(
    "test-reports/release-" + @async.now().to_string(),
  )
  let mut generate_candidate = false
  let mut verify_candidate = false
  let mut freeze_published = false
  let mut historical_replay = false
  let mut migrate_historical_revision = ""
  let mut freeze_evidence = ""
  let mut release_id = ""
  let mut registry_path = "tests/registry/registry.json"
  let mut active_output_path = "tests/release_runner/current/active-cases.json"
  let mut template_path = "tests/release_runner/current/candidate.json"
  let mut metadata_path = ""
  let mut output_path = "tests/release_runner/current/candidate.json"
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
      "--generate-candidate" => generate_candidate = true
      "--verify-candidate" => verify_candidate = true
      "--freeze-published" => freeze_published = true
      "--historical-replay" => historical_replay = true
      "--migrate-historical" if index + 1 < args.length() => {
        index += 1
        migrate_historical_revision = args[index]
      }
      "--freeze-evidence" if index + 1 < args.length() => {
        index += 1
        freeze_evidence = args[index]
      }
      "--release-id" if index + 1 < args.length() => {
        index += 1
        release_id = args[index]
      }
      "--registry" if index + 1 < args.length() => {
        index = index + 1
        registry_path = args[index]
      }
      "--active-output" if index + 1 < args.length() => {
        index = index + 1
        active_output_path = args[index]
      }
      "--template" if index + 1 < args.length() => {
        index = index + 1
        template_path = args[index]
      }
      "--metadata" if index + 1 < args.length() => {
        index = index + 1
        metadata_path = args[index]
      }
      "--output" if index + 1 < args.length() => {
        index = index + 1
        output_path = args[index]
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
  if migrate_historical_revision != "" {
    let root = workspace_root()
    migrate_historical_snapshots(
      root,
      migrate_historical_revision,
      registry_path=workspace_input(root, registry_path),
    )
    return
  }
  if generate_candidate {
    let root = workspace_root()
    let resolved_template = workspace_input(root, template_path)
    let resolved_registry = workspace_input(root, registry_path)
    let resolved_metadata = if metadata_path == "" {
      resolved_registry
    } else {
      workspace_input(root, metadata_path)
    }
    let resolved_active_output = workspace_input(root, active_output_path)
    let resolved_output = workspace_input(root, output_path)
    write_active_cases_index(resolved_registry, resolved_active_output, root~) catch {
      error => {
        @stdio.stderr.write(
          "release-runner: active case generation failed: \{error}\n",
        )
        @sys.exit(1)
        return
      }
    }
    write_candidate_manifest(
      root,
      resolved_template,
      resolved_metadata,
      resolved_output,
      registry_path=resolved_registry,
      active_path=resolved_active_output,
    ) catch {
      error => {
        @stdio.stderr.write(
          "release-runner: candidate generation failed: \{error}\n",
        )
        @sys.exit(1)
        return
      }
    }
    @stdio.stdout.write("Generated candidate manifest: \{resolved_output}\n")
    return
  }
  guard manifest_path is Some(manifest_path) else {
    @stdio.stderr.write(usage() + "\n")
    @sys.exit(2)
    return
  }
  let root = workspace_root()
  let manifest_path = workspace_input(root, manifest_path)
  registry_path = workspace_input(root, registry_path)
  let oracle_profile_path = workspace_input(root, oracle_profile_path)
  let run_started = @async.now()
  if freeze_published || verify_candidate {
    guard freeze_evidence != "" else { fail("--freeze-evidence is required") }
    let root = workspace_root()
    if freeze_published {
      freeze_published_snapshot(
        root,
        manifest_path,
        freeze_evidence,
        release_id,
        registry_path=workspace_input(root, registry_path),
        oracle_profile_path=workspace_input(root, oracle_profile_path),
        docker_path=docker,
      )
      println(
        "Published snapshot frozen after exact registry and MoonX verification",
      )
      return
    }
    validate_candidate_registry(
      root,
      manifest_path,
      freeze_evidence,
      registry_path=workspace_input(root, registry_path),
    ) catch {
      error => {
        write_release_preflight_failure(
          report_dir,
          manifest_path,
          "",
          registry_path,
          run_started,
          "candidate registry verification failed: " + error.to_string(),
        )
        @stdio.stderr.write(
          "release-runner: candidate registry verification failed: \{error}\n",
        )
        @sys.exit(1)
        return
      }
    }
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
      write_release_preflight_failure(
        report_dir,
        manifest_path,
        "",
        registry_path,
        run_started,
        "manifest infrastructure error: " + err.to_string(),
      )
      @stdio.stderr.write(
        "release-runner: manifest infrastructure error: \{err}\n",
      )
      @sys.exit(1)
      return
    }
  }
  if manifest.candidate == Some(true) &&
    suite != "validate" &&
    !list_only &&
    !verify_candidate {
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
  let base_path = resolve_base_manifest(
    base_directory.to_string(),
    manifest.base_manifest,
    manifest_path~,
  ) catch {
    error => {
      write_release_preflight_failure(
        report_dir,
        manifest_path,
        "",
        registry_path,
        run_started,
        "case source resolution failed: " + error.to_string(),
      )
      @stdio.stderr.write(
        "release-runner: case source resolution failed: \{error}\n",
      )
      @sys.exit(1)
      return
    }
  }
  let base = read_base_manifest(base_path) catch {
    err => {
      write_release_preflight_failure(
        report_dir,
        manifest_path,
        base_path,
        registry_path,
        run_started,
        "case infrastructure error: " + err.to_string(),
      )
      @stdio.stderr.write("release-runner: case infrastructure error: \{err}\n")
      @sys.exit(1)
      return
    }
  }
  let fixtures = filter_cases(selected_cases(manifest, base), commands, ids) catch {
    err => {
      write_release_preflight_failure(
        report_dir,
        manifest_path,
        base_path,
        registry_path,
        run_started,
        "selection invalid: " + err.to_string(),
      )
      @stdio.stderr.write("release-runner: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  // Published evidence is pinned by its manifest and remains replayable after
  // the working tree advances to a new candidate. Validate is the release-time
  // check that deliberately compares the manifest to local package versions.
  let validation = validate_release_manifest(manifest, base) +
    (if suite == "validate" && manifest.candidate == Some(true) {
      validate_package_versions(root, manifest) catch {
        error => ["package coordinate validation failed: " + error.to_string()]
      }
    } else {
      []
    })
  let resolved_path = @fs.realpath(manifest_path)
  let historical_root = root + "/tests/release_runner/historical/"
  let current_path = root + "/tests/release_runner/current/published.json"
  let frozen = manifest.candidate != Some(true) &&
    (resolved_path.has_prefix(historical_root) || resolved_path == current_path)
  if frozen {
    if resolved_path.has_prefix(historical_root) && !historical_replay {
      validation.push("historical manifests require --historical-replay")
    }
    validation.append(
      validate_frozen_case_binding(root, resolved_path, base_path),
    )
    registry_path = resolved_path + ".registry.json"
  }
  let registry = @registry.load(registry_path) catch {
    error => {
      write_release_preflight_failure(
        report_dir,
        manifest_path,
        base_path,
        registry_path,
        run_started,
        "registry infrastructure error: " + error.to_string(),
      )
      @stdio.stderr.write(
        "release-runner: registry infrastructure error: \{error}\n",
      )
      @sys.exit(1)
      return
    }
  }
  if frozen {
    if validation.is_empty() {
      validation.append(@registry.validate_frozen_registry(registry))
    }
  } else {
    validation.append(@registry.validate(registry))
  }
  try {
    if manifest.candidate == Some(true) {
      validation.append(
        validate_candidate_bindings(root, manifest, base, registry_path),
      )
    } else if !frozen {
      validation.append(@registry.validate_source_bindings(registry, root~))
      validation.append(
        @registry.validate_selected_cases(
          registry,
          selected_cases(manifest, base),
          root~,
        ),
      )
      for row in manifest.commands {
        if !registry.release_commands.any(reviewed => {
            reviewed.releasable &&
            reviewed.name == row.name &&
            reviewed.package_name == row.package_name &&
            reviewed.compare_profile == row.compare_profile &&
            reviewed.supported_options == row.supported_options &&
            reviewed.policy_sensitive == row.policy_sensitive
          }) {
          validation.push(
            row.name + ": published profile differs from authoritative registry",
          )
        }
      }
    }
  } catch {
    error =>
      validation.push("release source binding failed: " + error.to_string())
  }
  if !validation.is_empty() {
    write_release_preflight_failure(
      report_dir,
      manifest_path,
      base_path,
      registry_path,
      run_started,
      "release validation failed: " + validation.join("; "),
    )
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
    if report_dir is Some(directory) {
      write_report(
        directory,
        [],
        fixtures,
        false,
        Map([]),
        manifest_path,
        base_path,
        run_started,
        "",
        "",
        registry_path~,
      )
    }
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
  let mut oracle_image_digest = ""
  let mut oracle_versions_hash = ""
  let mut oracle_profile_id = ""
  if needs_oracle {
    let identity = try {
      oracle_profile_id = @testkit.read_oracle_profile(oracle_profile_path).id
      for fixture in fixtures {
        if case_supported_on_host(fixture, host_platform()) &&
          verification_level(fixture, true) == "differential" {
          guard registry.entries.any(entry => {
            entry.is_case() &&
            entry.case_id == fixture.id &&
            entry.oracle_profile != ""
          }) else {
            fail(
              fixture.id + ": differential requires a registered oracle profile",
            )
          }
        }
      }
      let required_profiles = registry.entries
        .filter(entry => {
          entry.oracle_profile != "" &&
          fixtures.any(fixture => entry.case_id == fixture.id)
        })
        .map(entry => entry.oracle_profile)
      @testkit.verify_oracle_image(
        oracle_image,
        docker_path=docker,
        profile_path=oracle_profile_path,
        expected_profile_path=root + "/tests/runner/image/profile.json",
        required_profile_ids=required_profiles,
      )
    } catch {
      error => {
        let detail = "oracle preflight failed: " + error.to_string()
        write_oracle_preflight_failure(
          report_dir,
          fixtures,
          manifest_path,
          base_path,
          run_started,
          detail,
          oracle_profile_id~,
          registry_path~,
        ) catch {
          report_error =>
            @stdio.stderr.write(
              "release-runner: cannot retain oracle preflight report: \{report_error}\n",
            )
        }
        @stdio.stderr.write("release-runner: " + detail + "\n")
        @sys.exit(1)
        return
      }
    }
    oracle_image_digest = identity.digest
    oracle_profile_id = identity.profile_id
    oracle_versions_hash = @testkit.sha256_text(identity.versions)
    // Pin all later Docker calls to the verified immutable image identity.
    oracle_image = identity.digest
  }
  let docker_user = if needs_oracle && !@platform.is_windows() {
    detect_docker_user() catch {
      _ => None
    }
  } else {
    None
  }
  let needs_http = fixtures.any(fixture => {
    case_supported_on_host(fixture, host_platform()) && is_network_case(fixture)
  })
  let needs_https = fixtures.any(fixture => {
    case_supported_on_host(fixture, host_platform()) &&
    fixture.args.any(arg => arg.contains("${HTTPS_BASE}"))
  })
  let executed_rows = manifest.commands.filter(row => {
    fixtures.any(fixture => {
      fixture.command == row.name &&
      case_supported_on_host(fixture, host_platform())
    })
  })
  let coordinates = executed_rows.map(row => {
    row.package_name + "@" + row.version
  })
  if report_dir is Some(directory) {
    retain_release_execution_failure(reports, () => {
      prepare_release_assets(executed_rows, moonx, timeout_ms, directory)
    })
    if !reports.is_empty() {
      write_report(
        directory,
        reports,
        fixtures,
        differential,
        timings,
        manifest_path,
        base_path,
        run_started,
        oracle_image_digest,
        oracle_versions_hash,
        oracle_profile_id~,
        registry_path~,
      )
      print_reports(reports, fixtures, differential)
      return
    }
  }
  let start_metadata = @testkit.collect_run_metadata(
    "release-" + run_started.to_string(),
    manifest_path~,
    case_corpus_path=base_path,
    registry_path~,
    oracle_profile_id~,
    oracle_image_digest~,
    moonx_coordinates=coordinates,
    started_at_ms=run_started,
  )
  let start_metadata = @testkit.with_oracle_versions_hash(
    start_metadata, oracle_versions_hash,
  )
  let start_metadata = @testkit.with_wasm_artifact_hash(
    start_metadata,
    @testkit.moonx_artifact_digest(coordinates),
  )
  retain_release_execution_failure(reports, () => {
    if needs_http || needs_https {
      @async.with_task_group <| group => {
        let mut http_base : String? = None
        let mut https_base : String? = None
        if needs_http {
          let (server, reader, url) = spawn_http_fixture_process(group)
          http_base = Some(url)
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
                    detail: "HTTP fixture cleanup failed: \{err}",
                  })
              }
            })
          })
        }
        if needs_https {
          let fixture_root = @fs.tmpdir(prefix="mooncmd-release-https-")
          let (server, url) = spawn_https_fixture_process(group, fixture_root)
          https_base = Some(url)
          group.add_defer(() => {
            server.cancel()
            @async.protect_from_cancel(() => {
              ignore(server.wait()) catch {
                err =>
                  reports.push({
                    id: "https-fixture-cleanup",
                    command: "fixture",
                    version: "",
                    category: "runner_infra",
                    detail: "HTTPS fixture cleanup failed: \{err}",
                  })
              }
              @fs.rmdir(fixture_root, recursive=true)
            })
          })
        }
        run_selected_cases(
          manifest, fixtures, moonx, docker, oracle_image, suite, timeout_ms, http_base,
          https_base, docker_user, reports, timings, jobs, report_dir,
        )
      }
    } else {
      run_selected_cases(
        manifest,
        fixtures,
        moonx,
        docker,
        oracle_image,
        suite,
        timeout_ms,
        None,
        None,
        docker_user,
        reports,
        timings,
        jobs,
        report_dir,
      )
    }
  })
  match report_dir {
    Some(directory) =>
      write_report(
        directory,
        reports,
        fixtures,
        differential,
        timings,
        manifest_path,
        base_path,
        run_started,
        oracle_image_digest,
        oracle_versions_hash,
        oracle_profile_id~,
        registry_path~,
        start_metadata~,
      )
    None => ()
  }
  print_reports(reports, fixtures, differential)
}
