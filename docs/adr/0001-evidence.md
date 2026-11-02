# ADR-0001: Observable Command Validation

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-03

## Decision

Deliver Wasm products through MoonX. Required development CI builds once per
host and runs applicable correctness suites on Linux, macOS and Windows;
Native is reserved for test tools. Mainline changes require a PR, the three
checks and actual-main validation. Resource observations and exact-version
published acceptance are separate manual workflows.

Workspace and published commands share execution and assertion mechanisms,
but retain independent expectations. Keep private-state/injected tests beside
their packages, CLI contracts in the existing registry and static corpora in
`tests/fixtures`. Missing fixtures fail; do not expose product APIs to move tests.

Use `tests/run.mbtx` as the public test entry for local work and CI. It discovers
the workspace, normalizes execution to its root, and checks/formats standalone
scripts explicitly. Generic infrastructure belongs to `tests/harness`, concrete
stateful assertions to `tests/scenarios`, and current CLI data to `tests/cases`.
Release policy belongs to `tests/release`, separately from executable identity
bindings. Retire old paths and modes without forwarding wrappers.

Maintain finite coverage reviews in `tests/coverage/review`. `index update`
generates quality, obligation, gap and candidate definitions; `index check`
rejects drift in CI. Generation completes into temporary outputs before any
derived file is replaced. Checked-in gap indexes describe definitions only;
actual passes require the fresh execution receipt and verifier. Published
coordinates and frozen expected cases remain independent and unchanged by this
process. Historical execution evidence remains in Git without replay adapters.

Coverage qualification requires complete typed or exact-byte assertions and a
completed execution/cleanup stage. Bind selectors to distinguishing positive
and negative controls, and stateful behavior to observed requests, deadlines,
file effects and owned-child lifecycle. Keep platform-specific qualification
explicit. Index checks and functional acceptance reject unresolved finite
obligations. Closing those gaps does not establish exhaustive semantics.

## Consequences and boundaries

- Assert stdout, stderr, status and file effects independently. Availability,
  semantic success, expected rejection and upstream agreement are different
  observations. Definition-bound receipts must reflect actual assertions.
- Use verified immutable Linux oracle images, tool inventories and checksums.
  Mutable tags and host executable hashes alone cannot establish upstream parity.
- Preserve original expectations and corpus bytes during migration. Keep aliases
  without duplicate execution; do not rewrite frozen published expectations.
- Keep platform exclusions explicit. Missing observers, incomplete selections,
  deadlines, uncertain cleanup and report failures cannot pass.
- Serialize timing-sensitive and lifecycle fixtures; compare metadata within
  each fixture and observe it before reads that may affect timestamps.
- Follow the separate [performance protocol](../../tests/benchmark/PROTECTION.md).
  A correctness pass, single RSS observation or selected timing pass cannot
  substitute for a complete performance gate.

Standalone help/version writes stdout, leaves live stdin untouched and exits
zero. Help starts with `Usage: <command>` and includes both metadata options;
version is exactly `<command> <package-version>\n`. Both end with a newline.

## Verification and reconsideration

The [test entry](../../tests/run.mbtx), [driver](../../tests/harness/driver/) and
[oracle verifier](../../tests/harness/oracle.mbt) implement these rules.
Owned children/containers must be cancelled, waited for and cleaned up;
missing cleanup remains an infrastructure failure. Host programs observe tests
or provide references and never implement product commands.

[latest.json](../../tests/release/latest.json) defines exact
published coordinates. Publish only through `moon publish`, then exercise real
MoonX resolution and three-platform acceptance. Record releases briefly in the
[changelog](../../CHANGELOG.md); raw results retain their original scope.

Development checks target roughly ten minutes and at most twenty, excluding
queue time. Preserve stage durations and failure diagnostics. A new backend,
oracle or lifecycle model needs equivalent observable guarantees. The retired
change-coverage audit, source/artifact push sealing and audited-push wrapper
are not current delivery gates.
