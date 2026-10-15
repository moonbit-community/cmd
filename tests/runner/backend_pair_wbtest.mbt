///|
test "scenario pairing normalizes only allocated fixture roots and listener origins" {
  let native = scenario_pair_bytes(
    b"/native/work/file http://127.0.0.1:1234/auth localhost:1234 foreign:42",
    "/native/work",
    Some("http://127.0.0.1:1234"),
  )
  let wasm = scenario_pair_bytes(
    b"/wasm/work/file http://127.0.0.1:5678/auth localhost:5678 foreign:42",
    "/wasm/work",
    Some("http://127.0.0.1:5678"),
  )
  assert_eq(native, wasm)
  assert_true(
    native !=
    scenario_pair_bytes(
      b"/wasm/work/changed http://127.0.0.1:5678/auth localhost:5678 foreign:42",
      "/wasm/work",
      Some("http://127.0.0.1:5678"),
    ),
  )
  assert_eq(scenario_pair_bytes(b"\xff", "/work", None), b"\xff")
  assert_eq(
    scenario_pair_bytes(
      b"http://other:1234",
      "/work",
      Some("http://127.0.0.1:1234"),
    ),
    b"http://other:1234",
  )
  assert_eq(
    scenario_pair_bytes(
      b"touch: /private/native/source unchanged /unrelated/source",
      "/native/work",
      None,
      filesystem_root="/private/native",
    ),
    scenario_pair_bytes(
      b"touch: /private/wasm/source unchanged /unrelated/source",
      "/wasm/work",
      None,
      filesystem_root="/private/wasm",
    ),
  )
  assert_true(
    scenario_pair_bytes(
      b"touch: /private/native/source /unrelated/changed",
      "/native/work",
      None,
      filesystem_root="/private/native",
    ) !=
    scenario_pair_bytes(
      b"touch: /private/wasm/source /unrelated/source",
      "/wasm/work",
      None,
      filesystem_root="/private/wasm",
    ),
  )
}

///|
test "timestamp pairing compares exact unchanged relations and rejects mutations" {
  let native : ScenarioTimestampObservation = {
    before_atime: "100:2",
    after_atime: "100:2",
    before_mtime: "90:3",
    after_mtime: "90:3",
  }
  let wasm : ScenarioTimestampObservation = {
    before_atime: "200:4",
    after_atime: "200:4",
    before_mtime: "190:5",
    after_mtime: "190:5",
  }
  let encode = (value : ScenarioTimestampObservation) => {
    @utf8.encode(@testkit.canonical_json(ToJson::to_json(value)))
  }
  assert_eq(
    scenario_timestamp_pair_relation(encode(native)),
    scenario_timestamp_pair_relation(encode(wasm)),
  )
  for
    changed in [
      { ..native, after_atime: "100:3", },
      { ..native, after_mtime: "90:4", },
    ] {
    let rejected = try {
      ignore(scenario_timestamp_pair_relation(encode(changed)))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "scenario pair snapshots detect byte and exit-status differences" {
  let directory = @fs.tmpdir(prefix="mooncmd-scenario-pair")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  for backend in ["native", "wasm"] {
    @fs.mkdir(directory + "/" + backend + "/work", recursive=true)
    @fs.write_file(directory + "/" + backend + "/stdout.bin", "same output")
    @fs.write_file(directory + "/" + backend + "/status.txt", "0")
    @fs.write_file(directory + "/" + backend + "/work/result", "same file")
  }
  let fixture : @testkit.Case = @json.from_json({
    "id": "process-lifecycle",
    "command": "env",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "comparison": "scenario",
  })
  let native = scenario_pair_snapshot(directory + "/native", fixture)
  assert_eq(native, scenario_pair_snapshot(directory + "/wasm", fixture))
  @fs.write_file(directory + "/wasm/status.txt", "7")
  assert_true(native != scenario_pair_snapshot(directory + "/wasm", fixture))
  @fs.write_file(directory + "/wasm/status.txt", "0")
  @fs.write_file(directory + "/wasm/work/result", "changed file")
  assert_true(native != scenario_pair_snapshot(directory + "/wasm", fixture))
}
