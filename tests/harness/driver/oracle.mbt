///|
async fn ensure_directory(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, recursive=true)
  }
}

///|
fn first_byte_difference(left : Bytes, right : Bytes) -> String {
  let shared = left.length().min(right.length())
  for index = 0; index < shared; index = index + 1 {
    if left[index] != right[index] {
      return "first byte differs at \{index}: candidate=\{left[index]} oracle=\{right[index]}"
    }
  }
  if left.length() != right.length() {
    "length differs after \{shared} equal bytes: candidate=\{left.length()} oracle=\{right.length()}"
  } else {
    "no byte difference"
  }
}

///|
async fn run_external_https_fixture(args : ArrayView[String]) -> Int32 {
  guard args.length() == 4 else { return 2 }
  let output = @process.redirect_to_file(args[3])
  @process.run(
    "openssl",
    [
      "s_server",
      "-accept",
      "127.0.0.1:0",
      "-cert",
      args[1],
      "-key",
      args[2],
      "-www",
    ],
    stdout=output,
    stderr=output,
    no_console_window=true,
  )
}

///|
fn expand_fixture_args(
  args : ArrayView[String],
  http_base : String,
  https_base : String,
) -> Array[String] {
  args.map(arg => {
    arg
    .replace_all(old="${HTTP_BASE}", new=http_base)
    .replace_all(old="${HTTPS_BASE}", new=https_base)
  })
}

///|
fn unexpected_oracle_transport_status(status : Int32, expected : Int32) -> Bool {
  [125, 126, 127].contains(status) && status != expected
}

///|
async fn run_case(
  fixture : OracleCase,
  bin_root : String,
  oracle_image : String,
  http_base : String,
  https_base : String,
  report_dir : String,
  docker_user : String,
) -> OracleCaseOutcome {
  let failures : Array[String] = []
  guard @harness.safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let root = report_dir + "/" + fixture.id
  if @fs.exists(root) {
    fail("evidence exists: " + root)
  }
  @fs.mkdir(root)
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  ensure_directory(candidate_root)
  ensure_directory(oracle_root)
  @harness.prepare_fixture(candidate_root, fixture, http_base~)
  @harness.prepare_fixture(oracle_root, fixture, http_base~)
  let stdin = fixture.input(root=candidate_root, http_base~)
  let environment = controlled_environment(
    @harness.expand_environment(fixture.environment, candidate_root, http_base~),
  )
  let args = @harness.expand_args(
    expand_fixture_args(fixture.args, http_base, https_base),
    candidate_root,
  )
  let networked = fixture.args.any(arg => {
      arg.contains("${HTTP_BASE}") || arg.contains("${HTTPS_BASE}")
    }) ||
    fixture.files.any(file => {
      file.content_hex
      .unwrap_or("")
      .to_lower()
      .contains("247b485454505f424153457d") ||
      file.content_text.unwrap_or("").contains("${HTTP_BASE}")
    })
  let candidate_before = if fixture.expected_rejection is Some(_) ||
    fixture.expected_files
    .unwrap_or([])
    .any(file => file.unchanged == Some(true)) {
    snapshot(
      candidate_root,
      observe=@harness.contract_observations(fixture),
      baseline=true,
      preserve_identity=true,
    )
  } else {
    []
  }
  let assertion_fixture = @harness.resolve_runtime_contract(
    fixture,
    candidate_root,
    http_base~,
  )
  let candidate_run = @harness.run_with_deadline(
    @harness.command_program(),
    @harness.command_args(bin_root, fixture.command, args),
    fixture.timeout_ms.unwrap_or(15000),
    stdin~,
    cwd=fixture.working_directory(candidate_root),
    extra_env=environment,
  ) catch {
    err => {
      failures.push("\{fixture.id}: candidate failed to start: \{err}")
      return { failures, local_contract: None, }
    }
  }
  let candidate = candidate_run.output
  @fs.write_file(root + "/candidate.stdout.bin", candidate.stdout)
  @fs.write_file(root + "/candidate.stderr.bin", candidate.stderr)
  if candidate_run.cleanup_error is Some(error) {
    return {
      failures: ["infrastructure: cleanup: " + error],
      local_contract: None,
    }
  }
  if candidate_run.timed_out {
    return {
      failures: ["candidate-timeout: partial streams retained"],
      local_contract: None,
    }
  }
  let contract_check = check_oracle_candidate_contract(
    fixture, assertion_fixture, candidate, candidate_root, candidate_before, http_base,
  )
  failures.append(contract_check.failures)
  let docker_args = [
    "run",
    "--user",
    docker_user,
    "--rm",
    "-i",
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
    oracle_root + ":" + oracle_root + ":rw",
    "-w",
    fixture.working_directory(oracle_root),
  ]
  if @harness.option_child_required(fixture) {
    let helper = @harness.option_child_path()
    docker_args.append(["-v", helper + ":" + helper + ":ro"])
  }
  let oracle_environment = controlled_environment(
    @harness.expand_environment(fixture.environment, oracle_root, http_base~),
  )
  for name, value in oracle_environment {
    if name != "PATH" {
      docker_args.push("-e")
      docker_args.push(name + "=" + value)
    }
  }
  docker_args.push("-e")
  docker_args.push("PATH=/oracle/bin")
  docker_args.push(oracle_image)
  docker_args.push(fixture.command)
  docker_args.append(
    @harness.expand_args(
      expand_fixture_args(fixture.args, http_base, https_base),
      oracle_root,
    ),
  )
  let oracle_run = @harness.run_oracle_with_deadline(
    "docker",
    docker_args,
    fixture.timeout_ms.unwrap_or(120000),
    evidence_dir=root + "/oracle.lifecycle",
    stdin=fixture.input(root=oracle_root, http_base~),
    inherit_env=true,
  ) catch {
    err => {
      failures.push("\{fixture.id}: oracle failed to start: \{err}")
      return { failures, local_contract: contract_check.local_contract, }
    }
  }
  let oracle = oracle_run.output
  @fs.write_file(root + "/oracle.stdout.bin", oracle.stdout)
  @fs.write_file(root + "/oracle.stderr.bin", oracle.stderr)
  if oracle_run.cleanup_error is Some(error) {
    return {
      failures: ["infrastructure: cleanup: " + error],
      local_contract: contract_check.local_contract,
    }
  }
  if oracle_run.timed_out {
    return {
      failures: ["infrastructure: oracle-timeout: partial streams retained"],
      local_contract: contract_check.local_contract,
    }
  }
  if unexpected_oracle_transport_status(oracle.status, fixture.expected_status) {
    return {
      failures: [
        "infrastructure: oracle unavailable, Docker status \{oracle.status}",
      ],
      local_contract: contract_check.local_contract,
    }
  }
  if fixture.expected_rejection is Some(reason) {
    if oracle.status != fixture.expected_status {
      failures.push("\{fixture.id}: upstream boundary oracle status mismatch")
    }
    if candidate.status == 0 ||
      !@harness.contains_bytes(candidate.stderr, reason) {
      failures.push(
        "\{fixture.id}: expected explicit rejection containing '\{reason}'",
      )
    }
    if candidate.stdout != b"" {
      failures.push("rejected operation wrote stdout")
    }
    if !snapshots_equal(
        candidate_before,
        snapshot(candidate_root, observe=fixture.observe.unwrap_or([])),
      ) {
      failures.push("\{fixture.id}: unsupported operation changed its fixture")
    }
    if failures.is_empty() {
      @fs.rmdir(root, recursive=true)
    }
    return { failures, local_contract: contract_check.local_contract, }
  }
  if candidate.status != fixture.expected_status {
    failures.push(
      "\{fixture.id}: candidate status \{candidate.status}, expected \{fixture.expected_status}",
    )
  }
  if oracle.status != fixture.expected_status {
    failures.push(
      "\{fixture.id}: oracle status \{oracle.status}, expected \{fixture.expected_status}",
    )
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
  if !@harness.bytes_equal(candidate_stdout, oracle_stdout) {
    failures.push(
      "\{fixture.id}: stdout mismatch; " +
      first_byte_difference(candidate_stdout, oracle_stdout),
    )
  }
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
  let stderr_matches = match fixture.expected_stderr_contains {
    Some(reason) if fixture.diagnostic_reason is Some(_) =>
      @harness.contains_bytes(candidate_stderr, reason) &&
      @harness.contains_bytes(oracle_stderr, reason)
    _ => @harness.bytes_equal(candidate_stderr, oracle_stderr)
  }
  if !stderr_matches {
    failures.push(
      "\{fixture.id}: stderr mismatch; " +
      first_byte_difference(candidate_stderr, oracle_stderr),
    )
  }
  let candidate_files = snapshot(
    candidate_root,
    observe=fixture.observe.unwrap_or([]),
  )
  let oracle_files = snapshot(
    oracle_root,
    observe=fixture.observe.unwrap_or([]),
  )
  if !snapshots_equal(candidate_files, oracle_files) {
    failures.push(
      "\{fixture.id}: filesystem mismatch\n  candidate=" +
      repr(candidate_files) +
      "\n  oracle=" +
      repr(oracle_files),
    )
  }
  if failures.is_empty() {
    @fs.rmdir(root, recursive=true)
  }
  { failures, local_contract: contract_check.local_contract, }
}
