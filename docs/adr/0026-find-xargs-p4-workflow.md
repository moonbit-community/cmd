# ADR-0026: Bound Find and Xargs Workflow Semantics

Status: Accepted
Date: 2026-09-04

## Context

`find` and `xargs` are frequently composed, but both can cross filesystem and
child-process authority boundaries. A compatibility extension must preserve
deterministic traversal, argument ordering, and policy visibility without
delegating to ambient host utilities.

## Decision

Use MoonBit filesystem metadata and direct process requests only. `find`
traverses sorted directory entries, evaluates metadata predicates without
following symlinks, batches `-exec ... +` under a fixed 64 KiB argv budget,
and performs `-delete` only in postorder. `xargs` exposes line, EOF, size, and
bounded parallel options; `-P` schedules finite task-group windows and
aggregates child classes without process-group cancellation. Parser and policy
failures happen before side-effecting actions.

## Evidence

The unified runner covers native semantic and pinned-oracle cases, while the
Wasm policy suite separately verifies allowed reads/processes and denied child
or mutation requests. All artifacts are pre-built and reused by the suites.

## Consequences

Common findutils workflows are available in a portable profile with stable
ordering and explicit resource limits. Ownership, link-target, locale, shell,
and process-group semantics remain outside the claim.

## Rollback

Remove only the P4 manifest/policy cases and restore the previous bounded
profiles if a portable runtime primitive or upstream differential contract
proves unavailable.
