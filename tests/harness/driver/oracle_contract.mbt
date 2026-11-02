///|
using @harness {
  safe_relative_path,
  snapshot,
  snapshots_equal,
  normalize_text,
  controlled_environment,
}

///|
type OracleCase = @harness.Case

///|
priv struct OracleCaseOutcome {
  failures : Array[String]
  local_contract : @harness.LocalContractReceipt?
}

///|
async fn check_oracle_candidate_contract(
  fixture : OracleCase,
  assertion_fixture : OracleCase,
  candidate : @harness.RunResult,
  root : String,
  baseline : Array[@harness.SnapshotEntry],
  http_base : String,
) -> OracleCaseOutcome {
  if fixture.comparison != Some("contract") {
    return { failures: [], local_contract: None, }
  }
  let failures = @harness.check_contract(
    assertion_fixture,
    candidate,
    root,
    http_base~,
  )
  failures.append(
    @harness.check_expected_files(
      assertion_fixture,
      root,
      http_base~,
      baseline~,
    ),
  )
  failures.append(@harness.check_runtime_contract(assertion_fixture, candidate))
  {
    failures,
    local_contract: Some({
      definition_sha256: @harness.json_digest(ToJson::to_json(fixture)),
      passed: failures.is_empty(),
      observations: if failures.is_empty() {
        [
          "status",
          "stdout",
          "stderr",
          ..@harness.contract_observations(fixture),
        ]
      } else {
        []
      },
    }),
  }
}
