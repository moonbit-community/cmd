///|
fn proof_build_errors(
  build : Json,
  snapshot : Json,
  completed : Int64,
  after : Int64,
) -> Array[String] {
  let errors : Array[String] = []
  if proof_array(proof_field(build, "assertion_sources")).is_empty() {
    errors.push("built assertion source inventory is empty")
  }
  if proof_field(build, "schema") != Json(1) ||
    proof_field(build, "status") != Json(0) {
    errors.push("test driver needs an actual successful current build receipt")
  }
  if proof_field(build, "assertion_sources") !=
    proof_field(
      proof_field(snapshot, "scenario_contracts"),
      "assertion_sources",
    ) {
    errors.push("built test assertion sources differ from executed definitions")
  }
  if proof_field(build, "driver_sha256") !=
    proof_field(snapshot, "driver_sha256") ||
    proof_text(proof_field(build, "driver_sha256")).length() != 64 {
    errors.push(
      "executing driver binary differs from the current successful build",
    )
  }
  let times : (Int64, Int64, Int64)? = Some(
    (
      @json.from_json(proof_field(build, "started_at_ms")),
      @json.from_json(proof_field(build, "completed_at_ms")),
      @json.from_json(proof_field(snapshot, "prepared_at_ms")),
    ),
  ) catch {
    _ => None
  }
  match times {
    Some((started, built, prepared)) =>
      if !(after <= started &&
        started <= built &&
        built <= prepared &&
        prepared <= completed) {
        errors.push(
          "driver build and actual execution are not in the current controller window",
        )
      }
    None =>
      errors.push("current driver build or execution timestamps are absent")
  }
  let arguments = proof_field(build, "arguments")
  let debug : Json = [
    "build", "--target", "native", "--deny-warn", "tests/runner", "tests/proofs",
  ]
  let release : Json = [
    "build", "--target", "native", "--deny-warn", "tests/runner", "tests/proofs",
    "--release",
  ]
  if proof_field(build, "program") != Json("moon") ||
    (arguments != debug && arguments != release) {
    errors.push("receipt is not the required Native test-tool build")
  }
  errors
}
