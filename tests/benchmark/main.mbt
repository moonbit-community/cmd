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
async fn append_jsonl(path : String, value : Json) -> Unit {
  @fs.write_file(
    path,
    value.stringify() + "\n",
    create_mode=OpenOrCreate,
    append=true,
  )
}

///|
async fn main {
  let args = @env.args()[1:]
  if args.is_empty() || args.contains("--help") {
    println(
      "Usage: benchmark panels|baseline|run|probe --wasm-root ABS --moonrun ABS --oracle-bin ABS --correctness-driver ABS --corpus-root ABS --report-dir FRESH [--baseline-wasm-root ABS] [--commands NAMES]\n       benchmark inventory [--manifest FILE] [--commands NAMES]\n       benchmark report --report-dir DIR\n       Default manifest: real.json (schema3). One data-driven genuine-corpus suite for every measured command. Independent local contracts run before timing. Panels require two windows of nine pairs; run retains105pairs. Only schema3 complete real-source workloads are supported.",
    )
    return
  }
  let options : Map[String, String] = Map([])
  let mut index = 1
  while index < args.length() {
    guard args.get(index + 1) is Some(value) else {
      fail("option requires a value: " + args[index])
    }
    guard [
      "--moonrun", "--wasm-root", "--oracle-bin", "--report-dir", "--manifest", "--corpus-root",
      "--baseline-wasm-root", "--probe-pairs", "--window", "--commands", "--correctness-driver",
    ].contains(args[index]) else {
      fail("unknown option: " + args[index])
    }
    guard !options.contains(args[index]) else {
      fail("duplicate option: " + args[index])
    }
    options[args[index]] = value
    index += 2
  }
  match args[0] {
    "panels" => if !run_panels(options) { @sys.exit(1) }
    "inventory" =>
      println(Json(functional_inventory(options)).stringify(indent=2))
    "run" => {
      require_frozen_timing_backend(options)
      guard !options.contains("--probe-pairs") && !options.contains("--window") else {
        fail(
          "diagnostic sampling requires probe; run retains its full formal sampling",
        )
      }
      if !run_functional(options, sample=true) {
        @sys.exit(1)
      }
    }
    "baseline" => if !run_functional(options, sample=false) { @sys.exit(1) }
    "probe" => {
      if !options.contains("--probe-pairs") {
        options["--probe-pairs"] = "9"
      }
      if !run_functional(options, sample=true) {
        @sys.exit(1)
      }
    }
    "report" => {
      guard options.get("--report-dir") is Some(directory) else {
        fail("report requires --report-dir")
      }
      println(@fs.read_file(directory + "/report.json").text())
    }
    _ => fail("expected run, baseline, probe, panels, inventory or report")
  }
}
