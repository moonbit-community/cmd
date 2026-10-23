///|
priv struct PilotWorkload {
  id : String
  behavior_id : String
  command : String
  input_bytes : Int32
  expected_status : Int32
  args : Array[String]?
  input_mode : String?
  stdout_check : String?
} derive(FromJson, ToJson)

///|
priv struct PilotManifest {
  schema : Int32
  published_manifest : String
  workloads : Array[PilotWorkload]
} derive(FromJson, ToJson)

///|
priv struct PublishedCommand {
  name : String
  package_name : String
  version : String
  published : Bool
} derive(FromJson)

///|
priv struct PublishedManifest {
  commands : Array[PublishedCommand]
} derive(FromJson)

///|
priv struct PilotProfile {
  schema : Int32
  role : String
  cache : String
  timeout_ms : Int32
  oracle_build_record : String
  locale : String
  timezone : String
  qualification : String
} derive(FromJson, ToJson)

///|
priv struct OracleBuildRoot {
  prefix : String
} derive(FromJson)

///|
priv struct ProfileObservation {
  program : String
  args : Array[String]
  status : Int32?
  stdout : String
  stderr : String
  error : String?
} derive(ToJson)

///|
priv struct TrialRecord {
  phase : String
  pair : Int32
  block : Int32?
  side : String
  observation : ProcessObservation
  correct : Bool
  detail : String
  stdout_path : String
  stderr_path : String
  stdout_bytes : Int64?
} derive(ToJson)

///|
priv struct RowContext {
  workload : PilotWorkload
  directory : String
  candidate : BenchmarkInvocation
  upstream : BenchmarkInvocation
  expected_stdout : String
  empty : String
  timeout_ms : Int32
}

///|
priv struct PilotRow {
  workload : PilotWorkload
  coordinate : String
  candidate : BenchmarkInvocation
  upstream : BenchmarkInvocation
  trials : Array[TrialRecord]
  samples : Array[PairedSample]
  result : RowResult
} derive(ToJson)

///|
async fn write_json(path : String, value : Json) -> Unit {
  @fs.write_file(path, value.stringify(indent=2) + "\n")
}

///|
async fn observe_profile(
  program : String,
  args : Array[String],
) -> ProfileObservation {
  try {
    let output = @shell.Cmd(program, args).output(timeout_ms=10000)
    {
      program,
      args,
      status: Some(output.exit_code()),
      stdout: output.stdout(),
      stderr: output.stderr(),
      error: None,
    }
  } catch {
    error =>
      {
        program,
        args,
        status: None,
        stdout: "",
        stderr: "",
        error: Some(error.to_string()),
      }
  }
}

///|
async fn prepare_input(path : String, size : Int32) -> Unit {
  let file = @fs.create(path)
  defer file.close()
  let chunk = Bytes::makei(65536, index => {
    if index % 64 == 63 {
      b'\n'
    } else {
      (97 + index % 26).to_byte()
    }
  })
  for _ in 0..<(size / 65536) {
    file.write(chunk)
  }
  if size % 65536 != 0 {
    file.write(chunk[:size % 65536].to_owned())
  }
}

///|
fn stdout_check(workload : PilotWorkload) -> String {
  workload.stdout_check.unwrap_or(
    if workload.command == "cat" {
      "input"
    } else {
      "empty"
    },
  )
}

///|
async fn workload_args(
  workload : PilotWorkload,
  input : String,
) -> Array[String] {
  let args = workload.args.unwrap_or([])
  if args.any(arg => arg.contains("${INPUT_TEXT}")) {
    let text = @fs.read_file(input).text()
    args.map(arg => arg.replace_all(old="${INPUT_TEXT}", new=text))
  } else {
    args
  }
}

///|
async fn prepare_expected(
  workload : PilotWorkload,
  input : String,
  empty : String,
  directory : String,
) -> String {
  let path = directory + "/expected.stdout.bin"
  match stdout_check(workload) {
    "empty" => empty
    "input" | "gzip-roundtrip" => input
    "input-newline" => {
      @fs.write_file(path, @fs.read_file(input).text() + "\n")
      path
    }
    "byte-count" => {
      @fs.write_file(path, workload.input_bytes.to_string() + "\n")
      path
    }
    "sha256" => {
      @fs.write_file(
        path,
        @testkit.sha256_bytes(@fs.read_file(input).binary()) + "  -\n",
      )
      path
    }
    other => fail("unknown stdout check: " + other)
  }
}

///|
// This initial gzip observation buffers only the registered 0/1/4 KiB inputs.
// Decoding and content comparison happen after the measured process exits.
async fn gzip_roundtrip(
  compressed : String,
  expected : String,
  decoded : String,
) -> Bool {
  let output = @fs.open(decoded, mode=WriteOnly, create_mode=CreateOrTruncate)
  defer output.close()
  let trailing = @gzipops.decode(
    @fs.read_file(compressed).binary(),
    output,
    false,
  )
  !trailing && files_equal(decoded, expected)
}

///|
async fn run_pair(
  context : RowContext,
  phase : String,
  pair : Int32,
  block : Int32?,
  order : PairOrder,
  trials : Array[TrialRecord],
) -> PairedSample? {
  let mut candidate_us = 0.0
  let mut upstream_us = 0.0
  let sides = match order {
    CandidateFirst => ["candidate", "upstream"]
    UpstreamFirst => ["upstream", "candidate"]
  }
  for side in sides {
    let invocation = if side == "candidate" {
      context.candidate
    } else {
      context.upstream
    }
    let stdout_path = context.directory + "/" + side + ".stdout.bin"
    let stderr_path = context.directory + "/" + side + ".stderr.bin"
    let observation = measure_invocation(
      invocation,
      stdout_path,
      stderr_path,
      context.timeout_ms,
    ) catch {
      error =>
        {
          elapsed_us: 0.0,
          status: None,
          timed_out: false,
          error: Some(error.to_string()),
        }
    }
    let mut detail = ""
    let mut stdout_bytes : Int64? = None
    let correct = try {
      if observation.timed_out ||
        observation.error is Some(_) ||
        observation.status != Some(context.workload.expected_status) {
        detail = "execution did not return the required status"
        false
      } else if !(if stdout_check(context.workload) == "gzip-roundtrip" {
          gzip_roundtrip(
            stdout_path,
            context.expected_stdout,
            context.directory + "/" + side + ".decoded.bin",
          )
        } else {
          files_equal(stdout_path, context.expected_stdout)
        }) {
        detail = "stdout failed the declared output check"
        false
      } else if !files_equal(stderr_path, context.empty) {
        detail = "stderr is not empty"
        false
      } else if !finite_positive(observation.elapsed_us) {
        detail = "elapsed duration is not finite and positive"
        false
      } else {
        stdout_bytes = Some(@fs.file_size(stdout_path))
        true
      }
    } catch {
      error => {
        detail = "output observation failed: " + error.to_string()
        false
      }
    }
    let trial = {
      phase,
      pair,
      block,
      side,
      observation,
      correct,
      detail,
      stdout_path,
      stderr_path,
      stdout_bytes,
    }
    trials.push(trial)
    // Keep each observation before the next invocation reuses its output files.
    append_jsonl(context.directory + "/trials.jsonl", ToJson::to_json(trial))
    if !correct {
      return None
    }
    if side == "candidate" {
      candidate_us = observation.elapsed_us
    } else {
      upstream_us = observation.elapsed_us
    }
  }
  Some({ candidate_us, upstream_us, })
}

///|
async fn append_jsonl(path : String, value : Json) -> Unit {
  @fs.write_file(
    path,
    value.stringify() + "\n",
    create_mode=OpenOrCreate,
    append=true,
  )
}

///|
async fn run_workload(
  workload : PilotWorkload,
  coordinate : String,
  moonx : String,
  oracle_bin : String,
  output : String,
  environment : Map[String, String],
  timeout_ms : Int32,
  cwd : String,
) -> PilotRow {
  let directory = output + "/" + workload.id
  @fs.mkdir(directory)
  let input = directory + "/input.bin"
  let empty = directory + "/empty.bin"
  prepare_input(input, workload.input_bytes)
  @fs.write_file(empty, b"")
  let args = workload_args(workload, input)
  let stdin_path = match workload.input_mode.unwrap_or("stdin") {
    "stdin" => input
    "operand" => empty
    other => fail("unknown input mode: " + other)
  }
  let candidate : BenchmarkInvocation = {
    program: moonx,
    args: [coordinate, "--", ..args],
    cwd,
    environment,
    stdin_path,
  }
  let upstream : BenchmarkInvocation = {
    program: oracle_bin + "/" + workload.command,
    args,
    cwd,
    environment,
    stdin_path,
  }
  let context = {
    workload,
    directory,
    candidate,
    upstream,
    empty,
    timeout_ms,
    expected_stdout: prepare_expected(workload, input, empty, directory),
  }
  let trials : Array[TrialRecord] = []
  let samples : Array[PairedSample] = []
  let plan = sampling_plan()
  let mut correct = true
  println(
    "running " + workload.id + " (5 warmup pairs, then 105 measured pairs)",
  )
  for index, order in plan.warmups {
    if run_pair(context, "warmup", index, None, order, trials) is None {
      correct = false
      break
    }
  }
  if correct {
    for pair in plan.pairs {
      match
        run_pair(
          context,
          "measured",
          pair.index,
          Some(pair.block),
          pair.order,
          trials,
        ) {
        Some(sample) => samples.push(sample)
        None => {
          correct = false
          break
        }
      }
    }
  }
  let row = {
    workload,
    coordinate,
    candidate,
    upstream,
    trials,
    samples,
    result: summarize_row(samples, correctness_ok=correct),
  }
  write_json(directory + "/row.json", ToJson::to_json(row))
  row
}

///|
async fn run_pilot(options : Map[String, String]) -> Bool {
  let started_at = @async.now()
  let moonx = options.get("--moonx").unwrap_or("")
  let oracle_bin = options.get("--oracle-bin").unwrap_or("")
  guard @path.Path(moonx).is_absolute() && @path.Path(oracle_bin).is_absolute() else {
    fail("--moonx and --oracle-bin require explicit absolute paths")
  }
  let cwd = @env.current_dir().unwrap_or(".")
  let output = @path.Path(
      options
      .get("--report-dir")
      .unwrap_or("test-reports/performance/pilot-" + @async.now().to_string()),
    )
    .resolve()
    .to_string()
  guard !@fs.exists(output) else {
    fail("report directory already exists: " + output)
  }
  let manifest_path = options
    .get("--manifest")
    .unwrap_or("tests/benchmark/manifest.json")
  let profile_path = options
    .get("--profile")
    .unwrap_or("tests/benchmark/profile.json")
  let manifest : PilotManifest = @json.from_json(
    @json.parse(@fs.read_file(manifest_path).text()),
  )
  let profile : PilotProfile = @json.from_json(
    @json.parse(@fs.read_file(profile_path).text()),
  )
  let oracle_record = @json.parse(
    @fs.read_file(profile.oracle_build_record).text(),
  )
  let oracle_root : OracleBuildRoot = @json.from_json(oracle_record)
  guard @fs.realpath(oracle_bin) == @fs.realpath(oracle_root.prefix + "/bin") else {
    fail(
      "--oracle-bin must match the selected native build record's bin directory",
    )
  }
  guard manifest.schema == 1 &&
    profile.schema == 1 &&
    profile.role == "delivery" &&
    profile.cache == "warm" &&
    profile.locale == "C" &&
    profile.timezone == "UTC" else {
    fail("expected schema-1 warm delivery pilot with C locale and UTC")
  }
  let published : PublishedManifest = @json.from_json(
    @json.parse(@fs.read_file(manifest.published_manifest).text()),
  )
  let registry = @registry.load("tests/registry/registry.json")
  let coordinates : Map[String, String] = Map([])
  for workload in manifest.workloads {
    guard @testkit.safe_relative_path(workload.id) && workload.input_bytes >= 0 else {
      fail("invalid workload ID or negative input size")
    }
    guard registry.entries.any(entry => {
      entry.behavior_id == workload.behavior_id &&
      entry.command == workload.command
    }) else {
      fail("workload has no matching registry behavior: " + workload.id)
    }
    let matches = published.commands.filter(row => {
      row.name == workload.command && row.published
    })
    guard matches.length() == 1 else {
      fail("requires one current published coordinate: " + workload.command)
    }
    coordinates[workload.id] = matches[0].package_name +
      "@" +
      matches[0].version
  }
  guard !manifest.workloads.is_empty() else { fail("pilot manifest is empty") }
  let environment = { "LC_ALL": "C", "LANG": "C", "TZ": "UTC" }
  guard @env.get_env_var("MOON_HOME") is Some(moon_home) && moon_home != "" else {
    fail("launch with the required MOON_HOME account prefix")
  }
  environment["MOON_HOME"] = moon_home
  @fs.mkdir(output, recursive=true)
  let probes = [
    observe_profile("moon", ["version", "--all"]),
    observe_profile(moonx, ["--version"]),
    observe_profile("uname", ["-a"]),
    observe_profile("git", ["rev-parse", "HEAD"]),
    observe_profile("git", ["status", "--short"]),
    observe_profile("df", ["-Pk", output]),
  ]
  if @testkit.host_platform() == "macos" {
    probes.append([
      observe_profile("/usr/bin/sw_vers", []),
      observe_profile("/usr/sbin/sysctl", [
        "-n", "machdep.cpu.brand_string", "hw.ncpu", "hw.memsize",
      ]),
      observe_profile("/usr/bin/pmset", ["-g", "batt"]),
    ])
  }
  let observed_commands : Array[String] = []
  for workload in manifest.workloads {
    let command = workload.command
    if observed_commands.contains(command) {
      continue
    }
    observed_commands.push(command)
    probes.push(observe_profile(oracle_bin + "/" + command, ["--version"]))
  }
  write_json(output + "/profile.json", {
    "started_at_ms": Json(started_at.to_string()),
    "configuration": ToJson::to_json(profile),
    "platform": Json(@testkit.host_platform()),
    "moonx": Json(moonx),
    "oracle_bin": Json(oracle_bin),
    "environment": ToJson::to_json(environment),
    "inherited_path": Json(@env.get_env_var("PATH")),
    "oracle_build_record": oracle_record,
    "observations": ToJson::to_json(probes),
  })
  write_json(output + "/manifest.json", ToJson::to_json(manifest))
  write_json(output + "/sampling-plan.json", ToJson::to_json(sampling_plan()))
  let rows : Array[PilotRow] = []
  for workload in manifest.workloads {
    rows.push(
      run_workload(
        workload,
        coordinates[workload.id],
        moonx,
        oracle_bin,
        output,
        environment,
        profile.timeout_ms,
        cwd,
      ),
    )
  }
  let passed = rows.all(row => row.result.verdict is Pass)
  write_json(output + "/report.json", {
    "schema": Json(1),
    "pilot": Json(true),
    "role": Json("delivery"),
    "passed": Json(passed),
    "started_at_ms": Json(started_at.to_string()),
    "ended_at_ms": Json(@async.now().to_string()),
    "rows": ToJson::to_json(rows),
  })
  println("delivery pilot report: " + output + "/report.json")
  passed
}

///|
async fn main {
  let args = @env.args()[1:]
  if args.is_empty() || args.contains("--help") {
    println(
      "Usage: benchmark run --moonx ABS --oracle-bin ABS [--report-dir DIR] [--manifest FILE] [--profile FILE]\n       benchmark report --report-dir DIR",
    )
    return
  }
  let options : Map[String, String] = Map([])
  let mut index = 1
  while index < args.length() {
    guard args.get(index + 1) is Some(value) else {
      fail("option requires a value: " + args[index])
    }
    guard ["--moonx", "--oracle-bin", "--report-dir", "--manifest", "--profile"].contains(
      args[index],
    ) else {
      fail("unknown option: " + args[index])
    }
    options[args[index]] = value
    index += 2
  }
  match args[0] {
    "run" => if !run_pilot(options) { @sys.exit(1) }
    "report" => {
      guard options.get("--report-dir") is Some(directory) else {
        fail("report requires --report-dir")
      }
      println(@fs.read_file(directory + "/report.json").text())
    }
    _ => fail("expected run or report")
  }
}
