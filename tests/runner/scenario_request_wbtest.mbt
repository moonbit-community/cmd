///|
test "scenario request pairs normalize decoded Windows roots without rewriting other arguments" {
  let native = "D:\\a\\cmd\\test-reports/backend-pair/native/work"
  let wasm = "D:\\a\\cmd\\test-reports/backend-pair/wasm/work"
  let record = (work : String, origin : String, cookie : String) => {
    @utf8.encode(
      (
        {
          "command": Json("wget"),
          "args": Json([
            "--save-cookies=" + work + "/wget.cookies",
            "--header=Cookie: " + cookie,
            "--header=X-Path: D:\\unchanged\\data",
            origin + "/set",
          ]),
        } : Json).stringify(indent=2),
    )
  }
  let native_record = record(native, "http://127.0.0.1:1234", "sid=fixture")
  let wasm_record = record(wasm, "http://127.0.0.1:5678", "sid=fixture")
  let normalized = scenario_request_pair_bytes(
    native_record,
    native,
    Some("http://127.0.0.1:1234"),
  )
  assert_eq(
    normalized,
    scenario_request_pair_bytes(
      wasm_record,
      wasm,
      Some("http://127.0.0.1:5678"),
    ),
  )
  let decoded = @json.parse(@utf8.decode(normalized))
  assert_true(
    decoded
    is {
      "command": String("wget"),
      "args": [
        String("--save-cookies=${WORK}/wget.cookies"),
        String("--header=Cookie: sid=fixture"),
        String("--header=X-Path: D:\\unchanged\\data"),
        String("${HTTP_BASE}/set"),
      ],
      ..
    },
  )
  assert_true(
    normalized !=
    scenario_request_pair_bytes(
      record(wasm, "http://127.0.0.1:5678", "sid=changed"),
      wasm,
      Some("http://127.0.0.1:5678"),
    ),
  )
  assert_true(@utf8.decode(native_record).contains("native/work"))
  assert_true(@utf8.decode(wasm_record).contains("wasm/work"))
}
