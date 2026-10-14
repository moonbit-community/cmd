///|
/// Keep completed rows when shared fixture startup or teardown aborts a suite.
/// The outer runner still serializes these rows and the explicit infrastructure
/// result with one run metadata record.
async fn retain_execution_failure(
  reports : Array[@testkit.CaseReport],
  backend : String,
  started : Int64,
  execute : async () -> Unit,
) -> Unit {
  execute() catch {
    error =>
      reports.push({
        id: "runner:execution-infrastructure",
        command: "runner",
        result: "infra",
        verification: "availability",
        stage: "execution-lifecycle",
        detail: error.to_string(),
        platform: @testkit.host_platform(),
        backend,
        source_version: "workspace",
        duration_ms: @async.now() - started,
        observations: [],
        missing_observations: [],
        evidence: None,
      })
  }
}

///|
/// A cancelled direct child is complete only after wait succeeds. Test-boundary
/// injection exercises the same propagation used by the retained cohorts.
async fn wait_for_direct_child(
  label : String,
  wait : async () -> Int32,
) -> Unit {
  @async.protect_from_cancel(() => {
    ignore(wait()) catch {
      error =>
        fail("cleanup infrastructure: " + label + ": " + error.to_string())
    }
  })
}
