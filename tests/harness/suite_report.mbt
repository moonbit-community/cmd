///|
pub fn suite_report(
  name : String,
  backend : String,
  start : Int64,
  failures : Array[String],
) -> CaseReport {
  {
    id: name,
    command: "suite",
    result: if failures.is_empty() {
      "pass"
    } else {
      "fail"
    },
    verification: if name == "policy" {
      "boundary"
    } else {
      "contract"
    },
    stage: "assertion",
    detail: failures.join("; "),
    platform: host_platform(),
    backend,
    source_version: "workspace",
    duration_ms: @async.now() - start,
    observations: ["status", "stdout", "stderr", "file-content"],
    missing_observations: [],
    local_contract: None,
    evidence: None,
  }
}
