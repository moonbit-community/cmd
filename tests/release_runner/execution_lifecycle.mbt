///|
/// Preserve completed release rows and make shared fixture failures visible to
/// report finalization. A fixture exception cannot become semantic acceptance.
async fn retain_release_execution_failure(
  reports : Array[CaseReport],
  execute : async () -> Unit,
) -> Unit {
  execute() catch {
    error =>
      reports.push({
        id: "release:execution-infrastructure",
        command: "runner",
        version: "",
        category: "runner_infra",
        detail: match error {
          Failure(message) => message
          _ => error.to_string()
        },
      })
  }
}
