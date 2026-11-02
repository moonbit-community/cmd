# Reviewed contract evidence

Coverage has three distinct owners. Manual reviews describe finite claims;
generated definitions validate those reviews against current tests; fresh run
receipts establish which claims were actually observed. Never copy a past
execution pass into a current definition or generate a review from case tags.

| Input | Maintained meaning |
| --- | --- |
| `review/contracts.json` | Reviewed CLI assertions, activation and remaining facets |
| `review/systems.json` | Reviewed system/stateful facets and boundaries |
| `review/scenarios.json` | Exact typed observations, command identity and dimensions |
| `review/gaps.json` | Independent classification of unresolved labels and work |
| `generated/definitions.json` | Derived obligations for live catalog labels and selected primary operations |
| `generated/gaps.json`, `generated/gaps.md` | Definition-only remaining work, without an execution status |

## Updating a claim

1. Add or strengthen a concrete assertion in `cases/` or `scenarios/`, preserving
   original expectations and corpus records. Register the executable identity.
2. Review the activation, expected values, observation dimensions, command,
   finite scope and remaining facets in the appropriate `review/` file. A
   rejection proves only that boundary; option spelling alone proves nothing.
3. Run `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/run.mbtx -- index update`
   and inspect the diff. Update a gap classification only when its evidence
   warrants it. Unknown, duplicate or stale classifications fail generation.
4. Run `index check` and a fresh `functional` execution. CI requires both.

The index command generates all derived outputs into a temporary directory
before comparison or replacement. `index check` does not edit committed files.
It also checks case quality and candidate release definitions. Neither mode
updates `release/latest.json` or its independent expected cases.
Definition inputs and derived files use repository-enforced LF endings so
byte checks and review digests are identical across hosts. This policy does
not normalize raw fixture payloads.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" CMD_TEST_REPORT_ROOT=/absolute/fresh-root moon run tests/run.mbtx -- functional
```

The controller builds the current Native driver between matching assertion
source snapshots. The runner saves selected case definitions, typed scenario
descriptors, metadata versions, driver identity and actual observations.
The verifier binds the successful build to the execution window and binary,
then validates result totals/hash, scenario sidecar hash, each required value,
platform and command against its reviewed descriptor. Missing, duplicate,
stale, skipped or mismatched results cannot qualify. Explicit platform
exclusions remain unqualified on that platform.

Linux differential results qualify an independent local facet only when the
exact/runtime/file checkers emit a successful typed local receipt with the
original definition digest and complete observed dimensions. Shared wrong
output, oracle-only cases and a differential label are insufficient.

Execution outputs, including `proofs.json` and its run-bound gap report, stay
under the fresh report root. Checked-in gap indexes contain definitions only.
CI retains concise summaries, stage durations and failure diagnostics. Existing
reports are never backfilled when definitions move or change.

The verifier's `--require-full true` additionally rejects unresolved claims
and excluded reviewed facets. The default verifies applicable reviewed claims
and lists remaining work. Neither mode establishes exhaustive semantics,
upstream parity, performance acceptance or publication acceptance. Release
`supported_options` is a separate authority and must not be expanded from
catalog labels mechanically. Historical results remain in Git.
