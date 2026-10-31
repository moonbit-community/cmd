# Reviewed contract evidence

`coverage.json` accounts for every live catalog label and separately records
selected primary operations. A reviewed definition names exact current CLI
contracts, a discriminating activation and a finite scope. Other spellings,
interactions and resource effects remain explicit remaining facets. The input
reviews are `coverage-reviewed.json` and `coverage-systems.json`; regenerate
with `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/proofs --target native -- --generate`.

This ledger does not declare all command semantics covered. Catalog labels
include options, language families and operands; release `supported_options`
is a separate selection authority. It must not be expanded mechanically from
this inventory. Cases with only tags, differential expectations, fragments,
nonactivating inputs or an uncalled historical helper cannot qualify an exact
portable contract. A documented rejection proves only its stated boundary.

Ordinary workspace CI joins the ledger to the actual fresh Wasm execution.
The runner saves selected case and typed scenario definitions, metadata
versions, assertion-source identities and the executing driver digest. The
controller builds the current Native driver between matching source snapshots.
The verifier binds that successful build to the actual execution window and
binary, then checks case definitions, result-stream totals/hash, scenario
sidecar hash and each required observed value against its reviewed descriptor.
Multi-command scenarios bind assertions to their actual command. Skips,
missing/duplicate results, changed expectations, wrong commands, different
backends/platforms and changed definitions cannot qualify. Explicit
platform exclusions remain unqualified on that platform. These snapshots bind
assertions; they do not restore the retired source-sealing/push workflow.

Use the same controller as CI; choose a fresh absolute report root locally:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" CMD_TEST_REPORT_ROOT=/absolute/fresh-root moon run tests/ci.mbtx -- functional
```

The default checks all applicable reviewed facets and reports unresolved
catalog claims separately. `--require-full true` additionally rejects any
unresolved claim or excluded reviewed facet. Neither mode claims exhaustive
compatibility, pinned upstream parity or general performance. Published exact
coordinate acceptance keeps its independent frozen expectations. Package
publication uses `moon publish` only; this mechanism creates no release package.

`coverage-gap-review.json` records the independent per-label work review;
`tests/proof_gaps.mbtx` regenerates JSON and readable indexes from the current
ledger, rejects unknown/duplicate/stale classifications, and optionally binds
them to an actual proof report. Existing assertion upgrades are separate from
new activated fixtures or observers. Counts refer to labels, not numbers of
tests. Historical narrow-scope reminders add no unresolved labels and cannot
override a newer typed scenario's current finite scope.

The checked-in [readable index](../registry/coverage-gaps.md) and
[JSON index](../registry/coverage-gaps.json) record the 2026-10-30 reconciliation:
180 new fixture/observer labels, 33 existing-fixture assertion upgrades and one
supplemental `yes` feature. They are dated evidence, not a live pass authority;
regenerate against current definitions and optionally the actual proof report.
Forty-four separate partial-facet reminders do not add unresolved labels.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/proof_gaps.mbtx -- --output /absolute/fresh-gaps.json --markdown /absolute/fresh-gaps.md
```
