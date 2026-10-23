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
| 2026-10-23 | [C1 shared producer and addition closure](2026-10-23-c1-shared-producer-closure/README.md) | Conservative shared producer scope and post-addition child artifacts; local validation in progress, remote acceptance pending |
| 2026-10-23 | [C1 Windows evidence fixture correction](2026-10-23-c1-windows-fixture-correction/README.md) | Verified actual Windows eight-test failure and path-normalization cause; fixture-only correction, actual Windows acceptance pending |
| 2026-10-23 | [C1 live report index correction](2026-10-23-c1-live-index-correction/README.md) | Narrow regular-file index updates to documented narrative scope while retaining historical, rename and type boundaries; acceptance pending |
| 2026-10-23 | [C1 remote correction](2026-10-23-c1-remote-correction/README.md) | Preserved first PR failure, checkout-conversion regression, Linux supplementary receipts and independent frozen-publication proof; remote acceptance pending |
| 2026-10-23 | [C1 content-bound scope implementation](2026-10-23-c1-scope/README.md) | Local full/shadow scope migration, separate full/current and old-side evidence proof; remote acceptance pending |
| 2026-10-23 | [Comprehensive startup inventory](2026-10-23-comprehensive-startup/README.md) | Frozen source inventory of all 79 commands and 12 core packages, and all 22 pending original issue acceptance bullets |
| 2026-10-23 | [C0 actual-main acceptance](2026-10-23-c0-acceptance/README.md) | Exact actual-main three-platform and coverage-audit acceptance; historical timeout cause remains unconfirmed |
| 2026-10-23 | [C0 oracle lifecycle investigation](2026-10-23-c0-investigation/README.md) | Empty-stdin controls, preserved mainline timeout evidence, reproduced orphan-container cleanup defect, repair validation and explicit acceptance boundaries |
| 2026-10-20 | [Stage 0 async 0.22.5 release](2026-10-20-stage0-release/README.md) | Core 0.7.0 and curl/mv/wget 0.2.3, verified registry uploads, local MoonX contracts, three-platform publication evidence and preserved partial snapshot |
| 2026-10-18 | [Unified metadata release](2026-10-15-metadata-release/README.md) | Core 0.6.0, 78 command patch releases, 79 verified uploads on October 17 UTC, exact-source three-platform CI, published acceptance and immutable freezing |
| 2026-10-18 | [Test-system recheck repairs](2026-10-14-test-system-closeout/README.md) | Unified coverage/provenance gates, lifecycle ownership, direct backend pairs and final three-platform source acceptance |
| 2026-10-11 | [Command follow-up audit](2026-10-11-command-followups/README.md) | 79-command inventory, 31 new-package ADR mappings and Native/Wasm/exact MoonX observations of four known fidelity deviations |
| 2026-10-11 | [P2 command release 0.1.0](2026-10-11-p2-release-0.1.0/README.md) | Four pure MoonBit command packages, core 0.4.0, three-platform CI, clean-cache exact MoonX redownload and 554-case final smoke acceptance |
| 2026-10-11 | [P2 command candidate](2026-10-11-p2-command-candidate.md) | Local-only strings, column, which and date packages, shared testkit environment expansion, candidate manifest validation and Native/Wasm contracts |
| 2026-10-11 | [Second command batch release 0.1.0](2026-10-11-release-0.1.0/README.md) | Sixteen pure MoonBit command packages, core 0.3.0, three-platform CI, serial registry publication and exact MoonX smoke acceptance |
| 2026-09-27 | [P0 command release 0.1.1](2026-09-27-release-0.1.1/README.md) | README/version refresh for eleven command packages, three-platform CI, registry verification and exact MoonX smoke acceptance |
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
