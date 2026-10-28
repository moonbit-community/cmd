# ADR-0001: Observable command validation

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-28
Revision: Validate the Wasm delivery path on three platforms; retire change
audits, Native product pairing and source/artifact sealing.

## Decision

The product is delivered as Wasm through MoonX. Development checks execute
current release Wasm artifacts on Linux, macOS and Windows. Native remains a
test-tool implementation detail. Each host builds once and reuses its artifacts.
There is no cross-platform build job on the required path.

Keep package behavior tests, actual CLI contracts and stateful scenarios.
Workspace and published commands share the same process/fixture/assertion
implementation. Published commands and their product children use exact
selected coordinates. Performance observations and full published acceptance
run manually, separately from ordinary PR checks.

Main requires a PR and the three platform checks, followed by actual-main
validation. The former coverage-audit, reviewed change declaration, scope
closure, per-test evidence adapter and audited-push wrapper are retired by the
2026-10-26 user decision. They must not be rebuilt under another name.

## Correctness and observations

### Repository-owned rg corpus and command contracts

Large static corpus data belongs in `tests/fixtures/rg`, not generated product
source. The 751 imported regex records retain their original bytes, capture
expectations, compile flags and bounds. Existing PikeVM, lazy-DFA and meta-regex
drivers remain package tests: moving them across module boundaries would require
exposing internal APIs. The small test-only loader fails on absent, malformed,
duplicate or incomplete corpus input. Existing per-engine exclusions remain;
corpus size is not an engine-coverage count.

Forty-four printer cases with equivalent CLI behavior moved into
`tests/cases/rg.json` and the existing registry. Original expected output remains
exact, with status and stderr checked through the common Wasm launcher. Old
`rg_compat_*` names remain aliases. The remaining 20 cases require injected
paths/timing, binary-conversion policy or decoding behavior and stay in the
printer package. Flags, engine state, Unicode tables and specialized failure
regressions also retain their package boundaries. Neither directory movement
nor passing a current command establishes new upstream parity.

Both layers run in the existing development workflow, without a new test
framework or product-to-test module dependency. These repository integration
fixtures require the checkout; standalone published module archives do not
carry them. See the [fixture ownership and provenance](../../tests/fixtures/rg/README.md).

Local migration validation (2026-10-28): all 751 records were compared field by
field with the compiled original constants, and all 44 extracted expectations
passed against the frozen starting Wasm command before their package wrappers
were removed. Final checks passed 1,626 Wasm tests, 118 test-tool tests and
2,109 functional checks with 19 skips and no failures. All 80 release-Wasm
command artifacts remain byte-identical; the adapter has no production
consumer. Strict checks, interfaces, formatting and dependency validation pass.
The initial missing-ignore-fixture failures and migration setup diagnostics
remain in `/private/tmp/cmd-rg-tests-20261028`; local backup
`backup/rg-tests-20261028` preserves the full starting tree. This does not
replace Linux/macOS/Windows CI, published acceptance or earlier unresolved
performance stability gates.

### Result interpretation

Availability, semantic contracts, upstream agreement and expected rejection are
different results. Missing observers, timeouts, startup failures and uncertain
cleanup cannot be passes. An excluded platform remains a documented skip.
Unknown selections and empty required suites fail. A count of passing tests
does not certify every possible option or input.

Keep independent expected stdout/stderr bytes, exit status and applicable file
effects. A product/upstream disagreement remains a failure even if an old
package test encoded the same defect. Correct faulty expectations only with
actual behavioral evidence. An expected rejection must check its diagnostic
and required unchanged state, with the support record retaining the missing
API and unlock condition.

The upstream reference remains an immutable image with an actual tool inventory
and pinned distribution/source checksums. Host PATH tools and mutable tags do
not establish upstream parity. Store the image identity once per run; command
rows do not need source, registry, environment or executable hash chains.

Timestamped, delayed and network fixtures run after independent tasks finish.
Earlier macOS observations showed intermittent atime changes under concurrency;
the cause was not established. Keep original assertions and do not retry them
automatically. Resume their parallel execution only after a reproducible fix
and repeated concurrent correctness runs.

Filesystem comparisons use relationships within a fixture, fixed timestamps
or explicit before/after observations. Do not compare raw inode identities or
unrelated wall clocks between candidate and oracle roots. Collect relevant
metadata before reads that can change atime; refresh before-command baselines
after observer reads.

## Process and container lifecycle

Direct children are cancelled and waited before cleanup completes. This does
not promise control over arbitrary grandchildren. Failed waits and output
reads are infrastructure failures, with captured output retained where possible.

Docker oracles retain invocation-owned container names and labels. Abnormal
cleanup removes only a verified owned container ID and verifies absence.
Uncertain creation or cleanup remains an infrastructure failure. Successful
`docker run --rm` keeps its fast path. See the historical C0 investigation for
the original reproduction; it is not current performance acceptance.

All product code, shared runtime code, fixtures, runners and automation remain
pure MoonBit. Host programs are allowed only for setup, observation and fixed
upstream references, never as implementations of the commands.

## Metadata and publication

Standalone `--help` writes usage and both metadata options to stdout, with a
final newline and status 0. Standalone `--version` writes exactly command name,
one space, package version and one newline, with empty stderr and status 0.
Neither operation may consume stdin. The shared metadata observer retains an
inherited descriptor and verifies its complete sentinel after the command exits.
Historical closed-stdin probes establish only their
status and stream observations; live-input checks must be reported separately.

The current published inventory has independent expected cases. Changing
workspace versions or help text must not change the expected bytes for an old
coordinate. Published dependencies are exercised by real MoonX execution after
upload. A workspace build cannot establish published dependency resolution.
No receipt/archive/freezing pipeline is maintained. Historical published manifests remain
unchanged. Dated report summaries are in CHANGELOG.md; removed reports are
recoverable from Git history with their original limitations.

## Cost and reconsideration

The target is approximately 10 minutes, normally below 15 and at most 20 for
required development checks, with queue time separately visible. Resource and
publication workflows have independent budgets. Record actual cold/warm job
durations and runner usage; a timeout is a failure, not a performance success.

Retire duplicate executions only when their assertions remain covered. Use the
changelog for dated migration results, not an ongoing audit service.
Reintroducing a product backend requires an explicit delivery decision and
its own supported-platform contract. Changing the oracle or lifecycle model
requires equivalent observable correctness and cleanup guarantees.

## Source review (2026-10-26)

The Wasm-only transition is `e61d1c6`/`894433a`/`40efae2`; test-tool build reuse is `bf5e02b`. Current authorities are [check.yml](../../.github/workflows/check.yml), [ci.mbtx](../../tests/ci.mbtx), [runner](../../tests/runner/), [metadata observer](../../tests/runner/metadata.mbt) and [oracle verification](../../tests/testkit/oracle.mbt). These implement the gates rather than the retired coverage system.
