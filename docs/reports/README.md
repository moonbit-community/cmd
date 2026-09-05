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
| 2026-08-26—2026-08-30 | [Foundation and command migration](2026-08-26-foundation.md) | Repository scope, package split, initial command batches, and policy boundary |
| 2026-09-02—2026-09-04 | [Oracle and unified runner](2026-09-02-oracle-runner.md) | Upstream baselines, pinned oracle, P0 migration, and the one-runner contract |
| 2026-09-04 | [P1-P5 workflow expansion](2026-09-04-p1-p5.md) | HTTP, text pipelines, find/xargs, and the bounded POSIX shell |
| 2026-09-05 | [P6-P8 language and filesystem](2026-09-05-p6-p8.md) | jq, make/xxd, and the pure MoonBit Native/Wasm filesystem subset |
| 2026-09-05 | [P9 compatibility closure](2026-09-05-p9.md) | Remaining command-local options, diagnostics, NUL records, and C-locale `tr` |
| 2026-09-05 | [Final audit and archival](2026-09-05-final-audit.md) | Generated artifacts, Wasm execution, differential evidence, CI reconciliation, and documentation audit |

## Reading rule

Read the report for historical intent, then verify a command in the support
record and the applicable ADR. A passing parser, help line, or smoke invocation
never promotes an option to full upstream compatibility. Native semantic tests,
pinned upstream differential tests, and Wasm policy tests remain separate
evidence families.

