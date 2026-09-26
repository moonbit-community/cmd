# Compatibility history

This directory is the historical archive for the command compatibility work.
It replaces the former execution-plan document, which was useful while the
work was in flight but became misleading after P0-P9 were delivered.

The current support authority is [`../compatibility.md`](../compatibility.md).
The architectural decisions that constrain the support surface are indexed in
[`../adr/README.md`](../adr/README.md). These reports explain what changed,
which evidence was collected, and which boundaries were deliberately retained;
they are not an alternative support matrix.

## Reports

| Date | Report | Scope |
| --- | --- | --- |
| 2026-09-26 | [P0 command release 0.1.0](2026-09-26-release-0.1.0/README.md) | Eleven pure MoonBit command packages, three-platform CI, sequential publication and exact MoonX smoke acceptance |
| 2026-09-21 | [0.2.0 publication and acceptance](2026-09-21-release-0.2.0/README.md) | Three-platform source gate, core-first publication receipts, fixed Linux oracle and exact-version MoonX results |
| 2026-09-21 | [Complete JSON migration and release gate](2026-09-21-json-migration/README.md) | 240 legacy invocations migrated with assertion maps, two-backend execution, remote CI and publication gate |
| 2026-09-21 | [Test cleanup implementation](2026-09-21-test-cleanup-implementation.md) | Shared testkit, judgment repair, case/fixture migration, ls/jq fixes, serialized validation and remaining external gates |
| 2026-09-21 | [Test-system audit](2026-09-21-test-system-audit.md) | README synchronization, runner duplication, CI gaps and proposed cleanup; no test deletion |
| 2026-09-20 | [0.2.0 fidelity candidate](2026-09-20-fidelity-implementation.md) | Released dependency upgrade, runtime regressions, shell sessions, make concurrency, HTTP auth/cookies and explicit public API gaps |
| 2026-09-19 | [Published command-fidelity audit](2026-09-19-command-fidelity-audit.md) | Actual MoonX behavior before the 0.2.0 changes |
| 2026-08-26—2026-08-30 | [Foundation and command migration](2026-08-26-foundation.md) | Repository scope, package split, initial command batches, and policy boundary |
| 2026-09-02—2026-09-04 | [Oracle and unified runner](2026-09-02-oracle-runner.md) | Upstream baselines, pinned oracle, P0 migration, and the one-runner contract |
| 2026-09-04 | [P1-P5 workflow expansion](2026-09-04-p1-p5.md) | HTTP, text pipelines, find/xargs, and the bounded POSIX shell |
| 2026-09-05 | [P6-P8 language and filesystem](2026-09-05-p6-p8.md) | jq, make/xxd, and the pure MoonBit Native/Wasm filesystem subset |
| 2026-09-05 | [P9 compatibility closure](2026-09-05-p9.md) | Remaining command-local options, diagnostics, NUL records, and C-locale `tr` |
| 2026-09-05 | [Final audit and archival](2026-09-05-final-audit.md) | Generated artifacts, Wasm execution, differential evidence, CI reconciliation, and documentation audit |
| 2026-09-06 | [P0 fixes](2026-09-06-p0-fixes.md) | `seq`, version metadata, `sh` diagnostics, and `jqlog` newline fixes |
| 2026-09-06 | [Published-version Runner baseline](2026-09-06-published-runner-baseline.md) | Pure MoonBit registry consumer runner, exact versions, fixtures, and failure classes |
| 2026-09-06 | [Published smoke regression](2026-09-06-published-smoke-regression.md) | `sh -s` positional-parameter defect and required `0.1.6` republish |

## Reading rule

Read the report for historical intent, then verify a command in the support
record and the applicable ADR. A passing parser, help line, or smoke invocation
never promotes an option to full upstream compatibility. Native semantic tests,
pinned upstream differential tests, and Wasm policy tests remain separate
evidence families.
