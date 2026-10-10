///|
using @testkit {
  safe_relative_path,
  snapshot,
  snapshots_equal,
  normalize_text,
  controlled_environment,
  oracle_request_name,
}

///|
type OracleCase = @testkit.Case

///|
struct CommandRow {
  name : String
  baseline : String
  status : String
  native : String
  wasm : String
  capabilities : Array[String]
} derive(FromJson, Debug)

///|
struct Manifest {
  schema : Int
  commands : Array[CommandRow]
  cases : Array[OracleCase]
} derive(FromJson, Debug)

///|
fn validate_manifest(manifest : Manifest) -> Array[String] {
  let failures : Array[String] = []
  if manifest.schema != 1 && manifest.schema != 2 {
    failures.push("manifest: expected schema 1, got \{manifest.schema}")
  }
  let catalog = @cli.command_catalog()
  if manifest.commands.length() != catalog.length() {
    failures.push(
      "manifest: expected \{catalog.length()} command rows, got \{manifest.commands.length()}",
    )
  }
  let rows : Map[String, Bool] = Map([])
  for row in manifest.commands {
    if rows.contains(row.name) {
      failures.push("manifest: duplicate command row '\{row.name}'")
    }
    rows[row.name] = true
    if !["unmeasured", "partial", "compatible", "exception"].contains(
        row.status,
      ) {
      failures.push("\{row.name}: invalid status '\{row.status}'")
    }
    if row.baseline == "" || row.native == "" || row.wasm == "" {
      failures.push(
        "\{row.name}: baseline and target classifications are required",
      )
    }
  }
  for contract in catalog {
    if !rows.contains(contract.name) {
      failures.push("manifest: missing command row '\{contract.name}'")
    }
  }
  let case_ids : Map[String, Bool] = Map([])
  for fixture in manifest.cases {
    if fixture.expected_rejection == Some("") {
      failures.push("\{fixture.id}: rejection reason must be nonempty")
    }
    if fixture.id == "" || case_ids.contains(fixture.id) {
      failures.push(
        "manifest: case IDs must be nonempty and unique: '\{fixture.id}'",
      )
    }
    case_ids[fixture.id] = true
    if !safe_relative_path(fixture.id) {
      failures.push("unsafe case ID: " + fixture.id)
    }
    failures.append(@testkit.contract_errors(fixture))
    for dimension in fixture.observe.unwrap_or([]) {
      if ![
          "content", "type", "mode", "identity", "symlink-target", "atime", "mtime",
          "ctime",
        ].contains(dimension) {
        failures.push("unknown observation: " + dimension)
      }
      if ["atime", "ctime"].contains(dimension) &&
        fixture.expected_rejection is None {
        failures.push(
          "time observations require a same-fixture boundary or scenario",
        )
      }
      if dimension == "mtime" &&
        fixture.expected_rejection is None &&
        fixture.files.any(file => file.mtime is None) {
        failures.push(
          "differential mtime requires fixed timestamps on every input",
        )
      }
    }
    if !rows.contains(fixture.command) {
      failures.push("\{fixture.id}: unknown command '\{fixture.command}'")
    }
    ignore(fixture.input()) catch {
      err => failures.push("\{err}")
    }
    for file in fixture.files {
      if !safe_relative_path(file.path) {
        failures.push("\{fixture.id}: unsafe fixture path '\{file.path}'")
      }
      ignore(
        @testkit.input_bytes(
          file.content_hex,
          file.content_text,
          fixture.id + " file " + file.path,
        ),
      ) catch {
        err => failures.push("\{err}")
      }
      match file.kind {
        Some("file") | Some("directory") | None =>
          if file.target is Some(_) {
            failures.push(
              "\{fixture.id}: regular fixture cannot have a symlink target",
            )
          }
        Some("symlink") | Some("hardlink") => {
          guard file.target is Some(target) && target != "" else {
            failures.push("\{fixture.id}: symlink fixture needs a target")
            continue
          }
          if @path.Path(target).is_absolute() {
            failures.push("\{fixture.id}: symlink target must be relative")
          }
        }
        Some(kind) =>
          failures.push("\{fixture.id}: unsupported fixture kind '\{kind}'")
      }
    }
    if fixture.delay_ms is Some(delay) && (delay < 0 || delay > 10000) {
      failures.push("\{fixture.id}: delay_ms must be between 0 and 10000")
    }
    for normalization in fixture.normalizations {
      if normalization.comment == "" {
        failures.push("\{fixture.id}: every normalization needs a comment")
      }
      if !["stdout", "stderr"].contains(normalization.field) {
        failures.push(
          "\{fixture.id}: unsupported normalization field '\{normalization.field}'",
        )
      }
      if !["temporary-path", "path-separator", "working-directory"].contains(
          normalization.rule,
        ) {
        failures.push(
          "\{fixture.id}: unsupported normalization rule '\{normalization.rule}'",
        )
      }
    }
  }
  failures
}

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
async fn run_external_https_fixture(args : ArrayView[String]) -> Int {
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
async fn spawn_https_fixture_process(
  group : @async.TaskGroup[Unit],
  root : String,
) -> (@process.Process, String) {
  let cert = @fs.realpath("tests/fixtures/http/cert.pem")
  let key = @fs.realpath("tests/fixtures/http/key.pem")
  let fixture_root = @fs.realpath("tests/fixtures/http")
  let log = @path.Path(root).join(Path("https.log")).to_string()
  let output = @process.redirect_to_file(log)
  let process = @process.spawn(
    group,
    "openssl",
    ["s_server", "-accept", "127.0.0.1:0", "-cert", cert, "-key", key, "-WWW"],
    cwd=fixture_root,
    stdout=output,
    stderr=output,
    no_console_window=true,
    no_wait=true,
  )
  for attempt = 0; attempt < 200; attempt = attempt + 1 {
    if @fs.exists(log) {
      let text = @fs.read_file(log).text()
      if text.find("ACCEPT ") is Some(index) {
        let suffix = text[index + 7:].to_owned()
        let line = suffix.split("\n").next().unwrap_or("").trim().to_owned()
        if line.rev_find(":") is Some(colon) {
          let port = @string.parse_int(line[colon + 1:].to_owned()) catch {
            _ => 0
          }
          if port > 0 {
            return (process, "https://127.0.0.1:\{port}")
          }
        }
      }
    }
    @async.sleep(10)
  }
  process.cancel()
  ignore(process.wait()) catch {
    _ => ()
  }
  fail("oracle-runner: HTTPS fixture did not report a listening port")
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
async fn run_case(
  fixture : OracleCase,
  bin_root : String,
  oracle_image : String,
  http_base : String,
  https_base : String,
  wasm : Bool,
  report_dir : String,
  docker_user : String,
) -> Array[String] {
  let failures : Array[String] = []
  guard @testkit.safe_relative_path(fixture.id) else { fail("unsafe case ID") }
  let root = report_dir + "/" + fixture.id
  if @fs.exists(root) {
    fail("evidence exists: " + root)
  }
  @fs.mkdir(root)
  let candidate_root = @path.Path(root).join(Path("candidate")).to_string()
  let oracle_root = @path.Path(root).join(Path("oracle")).to_string()
  ensure_directory(candidate_root)
  ensure_directory(oracle_root)
  @testkit.prepare_fixture(candidate_root, fixture, http_base~)
  @testkit.prepare_fixture(oracle_root, fixture, http_base~)
  let stdin = fixture.input(root=candidate_root, http_base~)
  let environment = controlled_environment(fixture.environment)
  let args = @testkit.expand_args(
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
  let candidate_before = if fixture.expected_rejection is Some(_) {
    snapshot(
      candidate_root,
      observe=fixture.observe.unwrap_or([]),
      baseline=true,
    )
  } else {
    []
  }
  let candidate_run = @testkit.run_with_deadline(
    if wasm {
      "moonrun"
    } else {
      @testkit.executable_path(bin_root, fixture.command)
    },
    if wasm {
      [@testkit.wasm_path(bin_root, fixture.command), "--", ..args]
    } else {
      args
    },
    fixture.timeout_ms.unwrap_or(15000),
    stdin~,
    cwd=fixture.working_directory(candidate_root),
    extra_env=environment,
  ) catch {
    err => {
      failures.push("\{fixture.id}: candidate failed to start: \{err}")
      return failures
    }
  }
  let candidate = candidate_run.output
  @fs.write_file(root + "/candidate.stdout.bin", candidate.stdout)
  @fs.write_file(root + "/candidate.stderr.bin", candidate.stderr)
  if candidate_run.cleanup_error is Some(error) {
    return ["infrastructure: cleanup: " + error]
  }
  if candidate_run.timed_out {
    return ["candidate-timeout: partial streams retained"]
  }
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
    oracle_root + ":/work:rw",
    "-w",
    fixture.working_directory("/work"),
  ]
  for name, value in environment {
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
    @testkit.expand_args(
      expand_fixture_args(fixture.args, http_base, https_base),
      "/work",
    ),
  )
  let oracle_run = @testkit.run_with_deadline(
    "docker",
    docker_args,
    fixture.timeout_ms.unwrap_or(120000),
    stdin=fixture.input(root="/work", http_base~),
    inherit_env=true,
  ) catch {
    err => {
      failures.push("\{fixture.id}: oracle failed to start: \{err}")
      return failures
    }
  }
  let oracle = oracle_run.output
  @fs.write_file(root + "/oracle.stdout.bin", oracle.stdout)
  @fs.write_file(root + "/oracle.stderr.bin", oracle.stderr)
  if oracle_run.cleanup_error is Some(error) {
    return ["infrastructure: cleanup: " + error]
  }
  if oracle_run.timed_out {
    return ["infrastructure: oracle-timeout: partial streams retained"]
  }
  if [125, 126, 127].contains(oracle.status) {
    return [
      "infrastructure: oracle unavailable, Docker status \{oracle.status}",
    ]
  }
  if fixture.expected_rejection is Some(reason) {
    if oracle.status != fixture.expected_status {
      failures.push("\{fixture.id}: upstream boundary oracle status mismatch")
    }
    if candidate.status == 0 ||
      !@testkit.contains_bytes(candidate.stderr, reason) {
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
    return failures
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
  if !@testkit.bytes_equal(candidate_stdout, oracle_stdout) {
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
      @testkit.contains_bytes(candidate_stderr, reason) &&
      @testkit.contains_bytes(oracle_stderr, reason)
    _ => @testkit.bytes_equal(candidate_stderr, oracle_stderr)
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
  failures
}
