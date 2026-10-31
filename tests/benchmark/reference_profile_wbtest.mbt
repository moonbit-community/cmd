///|
test "C-byte wc reference calibration is explicit and confined to native wc" {
  assert_true(
    benchmark_reference_profile("wc", wasm_baseline=true).contains(
      "native reference calibration is not applied",
    ),
  )
  for
    (command, native, expected) in [
      ("wc", true, Some("1")),
      ("wc", false, None),
      ("sort", true, None),
    ] {
    let environment = Map([("LC_ALL", "C")])
    apply_benchmark_reference_profile(environment, command, native)
    assert_eq(environment.get("POSIXLY_CORRECT"), expected)
    assert_eq(environment["LC_ALL"], "C")
  }
}
