///|
fn proof_result_errors(
  run : Json,
  results : Array[Json],
  actual_sha256 : String,
) -> Array[String] {
  let errors : Array[String] = []
  if proof_field(run, "results_sha256") != Json(actual_sha256) {
    errors.push("actual semantic result stream is absent or changed")
  }
  let passes = results
    .filter(row => proof_field(row, "result") == Json("pass"))
    .length()
  let failures = results
    .filter(row => {
      [Json("fail"), Json("infra")].contains(proof_field(row, "result"))
    })
    .length()
  let skips = results
    .filter(row => proof_field(row, "result") == Json("skip"))
    .length()
  if results.is_empty() || passes + failures + skips != results.length() {
    errors.push("empty or unknown semantic result status")
  }
  if proof_field(run, "passed") != Json(passes) ||
    proof_field(run, "failed") != Json(failures) ||
    proof_field(run, "skipped") != Json(skips) {
    errors.push("run totals disagree with actual semantic result rows")
  }
  errors
}
