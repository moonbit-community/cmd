///|
priv struct CiContext {
  event : String
  base : String
  head : String
  pr_head : String
  run_id : String
  attempt : String
} derive(FromJson, ToJson)

///|
fn ci_sha(value : String) -> Bool {
  value.length() == 40 &&
  value != "0000000000000000000000000000000000000000" &&
  value.iter().all(char => char is ('0'..<='9') || char is ('a'..<='f'))
}

///|
fn ci_positive_integer(value : String) -> Bool {
  !value.is_empty() &&
  !value.has_prefix("0") &&
  value.iter().all(char => char is ('0'..<='9'))
}

///|
fn ci_context_errors(
  context : CiContext,
  parents : ArrayView[String],
) -> Array[String] {
  let failures : Array[String] = []
  if !ci_sha(context.head) ||
    !ci_positive_integer(context.run_id) ||
    !ci_positive_integer(context.attempt) {
    failures.push("CI context requires exact SHA and positive run/attempt IDs")
  }
  match context.event {
    "pull_request" =>
      if !ci_sha(context.base) ||
        !ci_sha(context.pr_head) ||
        parents.length() != 2 ||
        parents.get(0) != Some(context.base) ||
        parents.get(1) != Some(context.pr_head) {
        failures.push(
          "PR audit requires the synthetic merge with exact target-base and PR-head parents",
        )
      }
    "push" =>
      if !ci_sha(context.base) || context.base == context.head {
        failures.push("push audit requires the nonempty before-to-head range")
      }
    "workflow_dispatch" =>
      if context.base != "" &&
        (!ci_sha(context.base) || context.base == context.head) {
        failures.push("manual audit base must identify a distinct exact commit")
      }
    "schedule" =>
      if context.base != "" {
        failures.push(
          "scheduled regression validation cannot claim a change range",
        )
      }
    _ => failures.push("unsupported CI event: " + context.event)
  }
  failures
}

///|
async fn ci_git(args : Array[String]) -> String {
  let result = @shell.Cmd("git", args).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("CI Git prerequisite failed: " + result.stderr())
  }
  result.stdout().trim().to_owned()
}

///|
async fn ci_require_clean_checkout() -> Unit {
  let result = @shell.Cmd("git", [
    "status", "--porcelain=v1", "--untracked-files=normal",
  ]).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("CI Git status failed: " + result.stderr())
  }
  guard result.stdout() == "" else {
    fail(
      "CI evidence requires a clean exact checkout\n" +
      "git status --porcelain=v1:\n" +
      result.stdout() +
      "git status stderr:\n" +
      result.stderr(),
    )
  }
}

///|
async fn ci_report_history_errors(
  base : String,
  head : String,
) -> Array[String] {
  // Compare only the current range; disabling renames exposes removal of an
  // existing report even when identical bytes appear at a new path.
  let result = @shell.Cmd("git", [
    "diff", "--name-only", "--no-renames", "--diff-filter=MDT", "-z", base, head,
    "--", "docs/reports/",
  ]).output(timeout_ms=15000)
  guard result.exit_code() == 0 else {
    fail("CI historical report lookup failed: " + result.stderr())
  }
  result
  .stdout()
  .split("\u0000")
  .map(path => path.to_owned())
  .filter(path => {
    ci_documentation_path(path) && path != "docs/reports/README.md"
  })
  .map(path => {
    "existing historical report cannot be modified, deleted or renamed: " + path
  })
  .collect()
}

///|
async fn ci_context() -> CiContext {
  let context : CiContext = {
    event: @env.get_env_var("GITHUB_EVENT_NAME").unwrap_or(""),
    base: @env.get_env_var("CMD_AUDIT_BASE").unwrap_or(""),
    head: @env.get_env_var("GITHUB_SHA").unwrap_or(""),
    pr_head: @env.get_env_var("CMD_AUDIT_PR_HEAD").unwrap_or(""),
    run_id: @env.get_env_var("GITHUB_RUN_ID").unwrap_or(""),
    attempt: @env.get_env_var("GITHUB_RUN_ATTEMPT").unwrap_or(""),
  }
  let parents = ci_git(["show", "-s", "--format=%P", "HEAD"])
    .split(" ")
    .filter(value => value != "")
    .map(value => value.to_owned())
    .collect()
  let failures = ci_context_errors(context, parents)
  guard failures.is_empty() else { fail(failures.join("; ")) }
  guard resolve_revision("HEAD") == context.head else {
    fail("CI checkout differs from event SHA")
  }
  if context.base != "" {
    guard resolve_revision(context.base) == context.base else {
      fail("CI base is not an exact commit")
    }
    ignore(ci_git(["merge-base", "--is-ancestor", context.base, context.head]))
  }
  ci_require_clean_checkout()
  context
}

///|
fn ci_receipt_context_errors(
  saved : CiContext,
  current : CiContext,
) -> Array[String] {
  let failures : Array[String] = []
  if saved.event != current.event ||
    saved.base != current.base ||
    saved.head != current.head ||
    saved.pr_head != current.pr_head ||
    saved.run_id != current.run_id ||
    !ci_positive_integer(saved.attempt) {
    failures.push(
      "platform receipt belongs to a different workflow run or source range",
    )
  }
  // A failed-job rerun keeps successful platform artifacts from earlier attempts.
  if saved.attempt.length() > current.attempt.length() ||
    (
      saved.attempt.length() == current.attempt.length() &&
      saved.attempt > current.attempt
    ) {
    failures.push("platform receipt claims a future workflow attempt")
  }
  failures
}
