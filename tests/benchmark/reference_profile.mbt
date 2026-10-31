///|
fn benchmark_reference_profile(
  command : String,
  wasm_baseline~ : Bool = false,
) -> String {
  if wasm_baseline {
    "frozen Wasm baseline; native reference calibration is not applied"
  } else if command == "wc" {
    "GNU wc C-byte whitespace with POSIXLY_CORRECT=1"
  } else {
    "registered native command profile"
  }
}

///|
fn apply_benchmark_reference_profile(
  environment : Map[String, String],
  command : String,
  native : Bool,
) -> Unit {
  // GNU wc adds nonbreaking-space classifications unless POSIXLY_CORRECT is
  // set, even under LC_ALL=C. The command's documented profile is C bytes.
  if native && command == "wc" {
    environment["POSIXLY_CORRECT"] = "1"
  }
}
