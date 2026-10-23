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

///|
async test "scenario pair snapshots bind both allocated network origins and retain other ports" {
  let directory = @fs.tmpdir(prefix="mooncmd-two-network-origins-")
  defer @fs.rmdir(directory, recursive=true)
  for
    (backend, http_port, wire_port) in [
      ("native", "1234", "2345"),
      ("wasm", "3456", "4567"),
    ] {
    let evidence = directory + "/" + backend
    @fs.mkdir(evidence + "/work", recursive=true)
    @fs.write_file(
      evidence + "/network-origin.txt",
      "http://127.0.0.1:" + http_port,
    )
    @fs.write_file(
      evidence + "/wire-origin.txt",
      "http://127.0.0.1:" + wire_port,
    )
    @fs.write_file(
      evidence + "/work/request.bin",
      "GET /wire-url/a%0D%0Ab HTTP/1.1\r\nHost: 127.0.0.1:" +
      wire_port +
      "\r\nCookie: sid=actual\r\n\r\n",
    )
    @fs.write_file(
      evidence + "/work/origins.txt",
      "http://127.0.0.1:" +
      http_port +
      " http://127.0.0.1:" +
      wire_port +
      " http://foreign:9999",
    )
  }
  let fixture : @testkit.Case = @json.from_json({
    "id": "network-transfer-boundaries",
    "command": "curl",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "comparison": "scenario",
  })
  let native = scenario_pair_snapshot(directory + "/native", fixture)
  assert_eq(native, scenario_pair_snapshot(directory + "/wasm", fixture))
  @fs.write_file(
    directory + "/wasm/work/origins.txt",
    "http://127.0.0.1:3456 http://127.0.0.1:4567 http://foreign:9998",
  )
  assert_true(native != scenario_pair_snapshot(directory + "/wasm", fixture))
  @fs.write_file(
    directory + "/wasm/work/origins.txt",
    "http://127.0.0.1:3456 http://127.0.0.1:4567 http://foreign:9999",
  )
  @fs.write_file(
    directory + "/wasm/work/request.bin",
    "GET /wire-url/changed HTTP/1.1\r\nHost: 127.0.0.1:4567\r\nCookie: sid=actual\r\n\r\n",
  )
  assert_true(native != scenario_pair_snapshot(directory + "/wasm", fixture))
}

///|
test "paired side reports preserve failures without dangling success evidence" {
  let native = {
    ..suite_report("fixture", "native", 0L, []),
    evidence: Some("removed/native"),
  }
  let wasm = {
    ..native,
    backend: "wasm",
    result: "fail",
    detail: "different output",
    evidence: Some("retained/wasm"),
  }
  let native_side = contract_pair_side(native)
  let wasm_side = contract_pair_side(wasm)
  assert_eq(
    ToJson::to_json(native_side),
    ToJson::to_json({ ..native, evidence: None, }),
  )
  assert_eq(ToJson::to_json(wasm_side), ToJson::to_json(wasm))
  let selected : Array[@testkit.Case] = [
    @json.from_json({
      "id": "fixture",
      "command": "echo",
      "args": [],
      "files": [],
      "environment": {},
      "expected_status": 0,
      "normalizations": [],
      "comparison": "contract",
    }),
  ]
  let reports = [
    native_side,
    wasm_side,
    pair_report(
      selected[0],
      "fail",
      "assertion",
      "stdout differs",
      0L,
      Some("retained"),
    ),
  ]
  assert_eq(
    paired_role_reports(reports, selected, "contract-native").map(row => {
      ToJson::to_json(row)
    }),
    [ToJson::to_json(native_side)],
  )
  assert_eq(
    paired_role_reports(reports, selected, "contract-wasm").map(row => {
      ToJson::to_json(row)
    }),
    [ToJson::to_json(wasm)],
  )
  assert_eq(
    paired_role_reports(reports, selected, "backend-pair").map(row => row.result),
    ["fail"],
  )
}

///|
test "paired role partition retains scenario aliases and boundary verification" {
  let fixture : @testkit.Case = @json.from_json({
    "id": "mv-windows-wasm-links-boundary",
    "command": "mv",
    "args": [],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
    "comparison": "scenario",
  })
  let scenario = {
    ..suite_report("scenario:" + fixture.id, "wasm", 0L, []),
    verification: "boundary",
  }
  let reports : Array[@testkit.CaseReport] = []
  append_scenario_reports(reports, fixture, scenario)
  let boundary = {
    ..suite_report("boundary", "native", 0L, []),
    verification: "boundary",
  }
  reports.push(boundary)
  assert_eq(
    paired_role_reports(reports, [fixture], "scenarios-wasm").map(row => row.id),
    [fixture.id, "scenario:" + fixture.id],
  )
  assert_eq(
    paired_role_reports(reports, [fixture], "contract-native").map(row => {
      ToJson::to_json(row)
    }),
    [ToJson::to_json(boundary)],
  )
  assert_true(
    paired_role_reports(reports, [fixture], "backend-pair").is_empty(),
  )
  assert_true(
    paired_role_reports(reports, [fixture], "scenarios-native").is_empty(),
  )
}
