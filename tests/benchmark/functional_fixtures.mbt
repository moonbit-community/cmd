///|
priv struct FunctionalWorkload {
  id : String
  command : String
  reference_behavior_id : String
  case_id : String?
  recipe : String?
  pending : String?
  corpus : CorpusSpec?
} derive(FromJson, ToJson)

///|
priv struct FunctionalManifest {
  schema : Int32
  published_manifest : String
  case_corpus : String
  workloads : Array[FunctionalWorkload]
  base_manifest : String?
  sweeps : Array[CorpusSweep]?
} derive(FromJson, ToJson)

///|
async fn fixture_child(args : ArrayView[String]) -> Unit {
  match args {
    ["emit", text] => @stdio.stdout.write(text)
    ["copy"] =>
      for ;; {
        guard @stdio.stdin.read_some(max_len=65536) is Some(bytes) else {
          break
        }
        @stdio.stdout.write(bytes)
      }
    _ => fail("unknown benchmark fixture child")
  }
}

///|
fn quote_child(path : String) -> String {
  "'" + path.replace_all(old="'", new="'\\''") + "'"
}

///|
fn functional_fixture(
  workload : FunctionalWorkload,
  cases : Array[@testkit.Case],
  helper : String,
) -> @testkit.Case raise {
  if workload.case_id is Some(id) {
    guard cases.iter().find_first(item => item.id == id) is Some(item) &&
      item.command == workload.command &&
      item.expected_rejection is None &&
      !item.args.contains("--help") &&
      !item.args.contains("--version") else {
      fail(
        "functional workload needs a real non-metadata fixture: " + workload.id,
      )
    }
    return item
  }
  let args : Array[String] = []
  let files : Array[Json] = []
  let mut stdin = ""
  let mut expected : String? = Some("")
  match workload.recipe {
    Some("mktemp") => {
      args.push("tmp.XXXXXX")
      expected = None
    }
    Some("realpath") => {
      args.push("f")
      files.push({ "path": "f", "content_text": "fixture\n" })
      expected = Some("${WORK}/f\n")
    }
    Some("tree") => {
      args.push(".")
      files.append([
        { "path": "d", "kind": "directory" },
        { "path": "f", "content_text": "fixture\n" },
      ])
      expected = None
    }
    Some("yes") => expected = None
    Some("gzip") => {
      args.append(["-n", "-c"])
      stdin = "fixture\n"
      expected = None
    }
    Some("env-child") => {
      args.append([helper, "--fixture-child", "emit", "child"])
      expected = Some("child")
    }
    Some("sh-child") => {
      args.append(["-c", quote_child(helper) + " --fixture-child emit child"])
      expected = Some("child")
    }
    Some("make-child") => {
      args.push("-s")
      files.push({
        "path": "Makefile",
        "content_text": Json(
          "all:\n\t" + quote_child(helper) + " --fixture-child emit child\n",
        ),
      })
      expected = Some("child")
    }
    Some("xargs-child") => {
      args.append(["-n", "1", "--", helper, "--fixture-child", "emit"])
      stdin = "one two\n"
      expected = Some("onetwo")
    }
    Some("sleep") => args.push("0.01")
    Some("timeout-child") => {
      args.append(["1", helper, "--fixture-child", "emit", "child"])
      expected = Some("child")
    }
    _ => fail("unknown functional recipe: " + workload.id)
  }
  let value : Map[String, Json] = {
    "id": Json(workload.id),
    "command": Json(workload.command),
    "args": Json(args),
    "files": Json(files),
    "stdin_text": Json(stdin),
    "environment": {},
    "normalizations": [],
    "expected_status": 0,
    "expected_stderr_text": "",
    "comparison": "exact",
  }
  if expected is Some(text) {
    value["expected_stdout_text"] = Json(text)
  }
  if workload.recipe == Some("realpath") {
    value["normalizations"] = [
      {
        "field": "stdout",
        "rule": "temporary-path",
        "comment": "Equivalent isolated fixture roots.",
      },
    ]
  }
  @json.from_json(Json::object(value))
}

///|
async fn reset_functional_fixture(
  root : String,
  fixture : @testkit.Case,
  http_base : String,
) -> Unit {
  if @fs.exists(root) {
    @fs.rmdir(root, recursive=true)
  }
  @fs.mkdir(root)
  @testkit.prepare_fixture(root, fixture, http_base~)
}

///|
async fn compare_functional_effects(
  left : String,
  right : String,
  dimensions : Array[String],
) -> Array[String] {
  let before = @testkit.snapshot(left, observe=dimensions, content=false)
  let after = @testkit.snapshot(right, observe=dimensions, content=false)
  if !@testkit.snapshots_equal(before, after) {
    return ["filesystem metadata or paths differ"]
  }
  let errors : Array[String] = []
  for entry in before {
    if entry.kind == "file" &&
      !files_equal(left + "/" + entry.path, right + "/" + entry.path) {
      errors.push("file content differs: " + entry.path)
    }
  }
  errors
}

///|
async fn check_generated_effects(
  recipe : String?,
  root : String,
  stdout : String,
) -> Array[String] {
  if recipe == Some("yes") {
    let bytes = bounded_capture(stdout)
    if bytes.length() != 4096 {
      return ["yes emitted an incorrect fixed-byte prefix"]
    }
    for index, byte in bytes {
      if byte != (if index % 2 == 0 { b'y' } else { b'\n' }) {
        return ["yes emitted an incorrect fixed-byte prefix"]
      }
    }
    return []
  }
  if recipe != Some("mktemp") {
    return []
  }
  let name = @fs.read_file(stdout).text()
  let entries = @testkit.snapshot(root, observe=["mode"], content=false)
  if !name.has_suffix("\n") {
    return ["mktemp output has no final newline"]
  }
  let name = name[:name.length() - 1].to_owned()
  guard entries is [entry] &&
    name == entry.path &&
    name.has_prefix("tmp.") &&
    name.length() == 10 &&
    entry.kind == "file" &&
    entry.metadata.get("mode") == Some("600") &&
    @fs.file_size(root + "/" + name) == 0L else {
    return ["mktemp output does not identify one private empty regular file"]
  }
  []
}

///|
async fn bounded_capture(path : String) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  guard file.size() <= 65536L else {
    fail(
      "small fixture assertion exceeds64KiB; use a streaming workload relation",
    )
  }
  file.read_exactly_at(file.size().to_int(), position=0L)
}

///|
async fn consume_yes(
  reader : &@io.Reader,
  output : @fs.File,
  count : Int32,
) -> Unit {
  let mut offset = 0
  while offset < count {
    guard reader.read_some(max_len=(count - offset).min(65536)) is Some(bytes) else {
      fail("yes stopped before the fixed-byte consumer")
    }
    output.write(bytes)
    offset += bytes.length()
  }
}

///|
async fn observe_yes(
  invocation : BenchmarkInvocation,
  stdout : String,
  stderr : String,
  timeout_ms : Int32,
) -> ProcessObservation {
  let capture = @fs.create(stdout)
  defer capture.close()
  let errors = @process.redirect_to_file(stderr)
  defer errors.close()
  let input = @process.redirect_from_file(invocation.stdin_path)
  let (reader, output) = @process.read_from_process()
  defer reader.close()
  let started = @bench.monotonic_clock_start()
  let mut error = None
  let status = @async.with_timeout_opt(timeout_ms, () => {
    @async.with_task_group(group => {
      let child = @process.spawn(
        group,
        invocation.program,
        invocation.args,
        stdin=input,
        stdout=output,
        stderr=errors,
        cwd=invocation.cwd[:],
        extra_env=invocation.environment,
        cancel_handler=@process.hard_cancel(),
      )
      consume_yes(reader, capture, 4096)
      reader.close()
      child.wait()
    })
  }) catch {
    failure => {
      error = Some(failure.to_string())
      None
    }
  }
  {
    elapsed_us: @bench.monotonic_clock_end(started),
    status,
    timed_out: status is None && error is None,
    error,
  }
}
