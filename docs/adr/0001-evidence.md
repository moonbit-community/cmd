# ADR-0001: Observable Command Validation

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

Deliver products as Wasm through MoonX. Required development CI builds once
per host and runs the applicable suites on Ubuntu, macOS and Windows. Native
is used for test tools only. Mainline changes require a PR, all three checks
and actual-main validation. Resource observations and exact-version published
acceptance are separate manual workflows.

Workspace and published commands share process, fixture and assertion code.
Published commands and their product children use exact selected coordinates.
Keep package tests for private state and injected failures; use the existing
contract registry for equivalent CLI behavior and tests/fixtures for static
corpora. Missing fixtures fail. Do not expose product APIs to relocate tests.

The retired change-coverage audit, source/artifact sealing and audited-push
wrapper are not current gates and must not be recreated under another name.

Current duplicate CLI cases have one canonical record with selectable aliases;
aliases do not schedule a second execution. Frozen published expectations remain
independent. Shared HTTP fixtures serve JSON cases and stateful cohorts; keep
counted retry and cross-request state checks distinct. Legacy assertions needed
only by the frozen published corpus run only in published mode.

## Evidence rules

- Assert stdout, stderr, exit status and relevant file effects independently.
  Availability, semantic success, expected rejection and upstream agreement
  are different results. Missing observers, deadlines, empty required selections,
  uncertain cleanup and report failures cannot pass.
- Use an immutable Linux oracle image with verified tool inventory and
  distribution/source checksums. Host PATH tools and mutable tags are not
  parity evidence. Keep platform exclusions explicit.
- Preserve original expectations and corpus bytes during migrations. Correct
  a faulty expectation only with behavioral evidence. Expected rejections
  must assert their diagnostic and required unchanged state.
- Run timestamp-sensitive, delayed and lifecycle fixtures serially. Compare
  metadata relationships within each fixture; collect metadata before reads
  that may change atime. Do not compare unrelated inode numbers or clocks.
- Keep failed and incomplete timing windows failed. Apply the separate
  [performance protection protocol](../../tests/benchmark/PROTECTION.md);
  correctness or a single RSS observation cannot establish performance acceptance.

The rg corpus retains 751 imported records and per-engine exclusions. Its
engine drivers and injected printer tests stay package-local; CLI-equivalent
printer cases use the common runner. Counts are not claims of complete engine
coverage. See [fixture provenance](../../tests/fixtures/rg/README.md).

## Lifecycle and metadata

Cancel and wait for owned direct children before cleanup. Keep pipes alive
until pending task-group I/O has finished cancellation. Docker cleanup may
remove only verified invocation-owned containers and must verify absence.
These guarantees do not extend to arbitrary grandchildren or forced machine
termination. Host programs may observe tests or provide pinned oracles, never
implement a product command.

Standalone help/version write to stdout, leave stdin untouched and exit zero.
Help starts with `Usage: <command>`, includes both metadata options and ends
with a newline. Version is exactly `<command> <package-version>\n`.
The live-input observer verifies an inherited sentinel after exit; old
closed-stdin captures do not establish this property.

## Publication and cost

[latest.json](../../tests/release_runner/current/latest.json) and its separate
case snapshot define published acceptance. Workspace changes never rewrite
old-coordinate expectations. Exercise actual MoonX dependency resolution after
upload; a workspace build is insufficient. Release results remain dated in
[CHANGELOG.md](../../CHANGELOG.md).

Benchmark defaults select that same accepted inventory and matching independent
case corpus. Retired source/provenance/registry archives live in Git at 234f960,
not in the active checkout. Historical measurements keep their original
coordinates; changing defaults does not requalify an old result.

Required development checks target roughly ten minutes, normally below fifteen
and at most twenty, excluding queue time. Report actual stage durations and
failure diagnostics. Retire duplicate executions only when their assertions
remain covered. A new product backend, oracle or lifecycle model requires an
explicit decision and equivalent observable guarantees.

Implementation: [workflow](../../.github/workflows/check.yml),
[CI driver](../../tests/ci.mbtx), [runner](../../tests/runner/),
[metadata observer](../../tests/runner/metadata.mbt),
[oracle verification](../../tests/testkit/oracle.mbt).
