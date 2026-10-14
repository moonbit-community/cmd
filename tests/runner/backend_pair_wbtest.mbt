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
