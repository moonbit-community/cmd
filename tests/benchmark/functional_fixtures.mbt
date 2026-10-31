///|
priv struct RealInput {
  source : NaturalSource
  target : String
} derive(FromJson, ToJson)

///|
priv struct FunctionalWorkload {
  id : String
  command : String
  reference_behavior_id : String
  recipe : String?
  source : NaturalSource?
  other_source : NaturalSource?
  args : Array[String]?
  expected_status : Int32?
  expected_stdout : String?
  transport : String?
  chunk_bytes : Int32?
  sink : String?
  sink_chunk_bytes : Int32?
  sink_delay_ms : Int32?
  inputs : Array[RealInput]?
  mode : String?
  facets : Array[String]?
  expected_stderr : String?
  output_relation : String?
} derive(FromJson, ToJson)

///|
priv struct FunctionalManifest {
  schema : Int32
  case_corpus : String
  workloads : Array[FunctionalWorkload]
} derive(FromJson, ToJson)

///|
fn functional_fixture(workload : FunctionalWorkload) -> @testkit.Case raise {
  let args = workload.args.unwrap_or([])
  guard !args.any(arg => ["--help", "--version"].contains(arg)) else {
    fail("metadata cannot replace a real performance operation: " + workload.id)
  }
  let value : Map[String, Json] = {
    "id": Json(workload.id),
    "command": Json(workload.command),
    "args": Json(args),
    "files": [],
    "environment": {},
    "normalizations": [],
    "expected_status": workload.expected_status.unwrap_or(0),
    "expected_stderr_text": Json(workload.expected_stderr.unwrap_or("")),
    "comparison": "exact",
  }
  if workload.output_relation == Some("record-multiset") {
    value["stdout_order"] = "lines"
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
