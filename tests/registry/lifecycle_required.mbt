///|
/// This reviewed minimum is independent of the editable lifecycle registry.
/// Adding evidence is allowed; removing these obligations requires a code review.
fn required_lifecycle_assertions() -> Array[(String, Array[String])] {
  [
    ("candidate-start-failure", ["infra-result", "failure-evidence-retained"]),
    (
      "moonx-asset-missing",
      [
        "asset-unavailable-classification", "execution-evidence-retained", "no-semantic-promotion",
      ],
    ),
    (
      "registry-transport-failure",
      [
        "registry-transport-classification", "execution-evidence-retained", "no-semantic-promotion",
      ],
    ),
    (
      "docker-unavailable",
      [
        "missing-executable-rejected", "oracle-infrastructure-diagnostic", "profile-retained",
      ],
    ),
    (
      "oracle-digest-mismatch",
      ["digest-mismatch-rejected", "inventory-not-launched-after-mismatch"],
    ),
    (
      "oracle-version-mismatch",
      ["version-mismatch-rejected", "inventory-selects-immutable-digest"],
    ),
    (
      "partial-stdout-stderr",
      ["stdout-retained-on-timeout", "stderr-retained-on-timeout"],
    ),
    (
      "deadline-timeout",
      [
        "deadline-expires", "direct-child-exit-status-collected", "cleanup-completes",
      ],
    ),
    (
      "direct-child-reaping",
      [
        "deadline-expires", "direct-child-exit-status-collected", "direct-child-pid-absent-after-return",
      ],
    ),
    (
      "cleanup-failure",
      [
        "cleanup-infra-classification", "cleanup-failure-fixture-retained", "candidate-status-and-streams-retained",
        "no-success-observations",
      ],
    ),
    (
      "direct-child-cleanup-error",
      [
        "cleanup-error-overrides-exit-and-timeout", "candidate-streams-and-fixture-retained",
        "oracle-not-run-after-cleanup-error", "infra-report-retained", "no-semantic-promotion",
      ],
    ),
    (
      "fixture-creation-failure",
      ["fixture-infra-classification", "partial-fixture-evidence-retained"],
    ),
    (
      "fixture-snapshot-failure",
      [
        "snapshot-infra-classification", "candidate-status-retained", "candidate-streams-retained",
        "no-success-observations",
      ],
    ),
    (
      "metadata-observer-unavailable",
      [
        "missing-stat-rejected", "observation-unavailable-diagnostic", "fixture-bytes-preserved",
      ],
    ),
    (
      "http-fixture-lifecycle",
      [
        "http-loopback-startup", "response-body-observed", "listener-observer-positive-control",
        "no-listen-owner-after-joined-cleanup",
      ],
    ),
    (
      "https-fixture-lifecycle",
      [
        "https-subprocess-startup", "response-body-observed", "untrusted-certificate-rejected",
        "direct-child-waited", "listening-port-rebind-after-cleanup",
      ],
    ),
    (
      "concurrent-report-writes",
      ["one-writer-wins", "saved-rows-preserved", "write-lock-released"],
    ),
    (
      "report-directory-conflict",
      ["existing-evidence-rejected", "prior-evidence-bytes-preserved"],
    ),
    (
      "platform-skip",
      ["no-launch-on-skip", "no-fixture-on-skip", "skip-classification"],
    ),
    (
      "empty-or-unknown-selection",
      [
        "unknown-command-rejected", "unknown-case-rejected", "empty-selection-rejected",
      ],
    ),
    (
      "scenario-serial-execution",
      ["maximum-one-active-scenario", "completion-before-next-start"],
    ),
    (
      "published-smoke-serialization",
      ["maximum-one-active-smoke-candidate", "completion-before-next-start"],
    ),
    ("failure-evidence-retention", ["work-directory-retained"]),
    ("successful-fixture-cleanup", ["successful-work-directory-removed"]),
    (
      "result-verification-classification",
      ["availability-not-semantic", "infra-category-mapping"],
    ),
    (
      "report-aggregation",
      ["all-case-rows-retained", "run-metadata-reference-retained"],
    ),
  ]
}

///|
/// Completeness applies to the workspace matrix, not small binding fixtures.
fn validate_lifecycle_completeness(
  lifecycle : LifecycleRegistry,
) -> Array[String] {
  let failures : Array[String] = []
  for (id, assertions) in required_lifecycle_assertions() {
    let matches = lifecycle.cases.filter(item => item.id == id)
    guard matches.length() == 1 else {
      failures.push(
        "lifecycle: required proven case must occur exactly once '\{id}'",
      )
      continue
    }
    let item = matches[0]
    if item.status != "proven" {
      failures.push("lifecycle: required case must remain proven '\{id}'")
    }
    for assertion in assertions {
      if !item.proves.contains(assertion) {
        failures.push(
          "lifecycle: missing required assertion '\{assertion}' in '\{id}'",
        )
      }
    }
  }
  let boundary = lifecycle.cases.filter(item => {
    item.id == "grandchild-process-boundary"
  })
  if boundary.length() != 1 {
    failures.push(
      "lifecycle: required grandchild-process-boundary must occur exactly once",
    )
  } else {
    let item = boundary[0]
    if item.status != "deferred" ||
      item.test_ref != "" ||
      !item.proves.is_empty() ||
      !item.limitations.contains(
        "direct-child cleanup is not a process-tree ownership guarantee",
      ) {
      failures.push(
        "lifecycle: grandchild-process-boundary must retain its explicit deferred ownership limitation",
      )
    }
  }
  failures
}
