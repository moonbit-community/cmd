///|
/// Keep completed rows when shared fixture startup or teardown aborts a suite.
/// The outer runner still serializes these rows and the explicit infrastructure
/// result with one run metadata record.
async fn retain_execution_failure(
  reports : Array[@harness.CaseReport],
  backend : String,
  started : Int64,
  execute : async () -> Unit,
) -> Unit {
  execute() catch {
    error =>
      @harness.append_report(reports, {
        id: "runner:execution-infrastructure",
        command: "runner",
        result: "infra",
        verification: "availability",
        stage: "execution-lifecycle",
        detail: error.to_string(),
        platform: @harness.host_platform(),
        backend,
        source_version: "workspace",
        duration_ms: @async.now() - started,
        observations: [],
        missing_observations: [],
        local_contract: None,
        evidence: None,
      })
  }
}
