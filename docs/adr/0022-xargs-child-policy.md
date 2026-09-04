# ADR-0022: Keep Xargs Direct-Child Execution Policy-Visible

Status: Accepted
Date: 2026-09-04

## Context

`xargs` turns input into process argv batches. Allowing arbitrary ambient
program execution would bypass Wasm policy.

## Decision

Support whitespace/NUL parsing, quotes/backslashes, `-0`, `-r`, `-t`, `-n`,
`-L`, `-s`, `-E`, `--show-limits`, and `-I`. Execute each batch as one direct
child request. `-P` uses bounded task-group windows; a window stops scheduling
after terminal launch/signal classes and aggregates ordinary child failures.
No shell or ambient process authority is inherited.

## Evidence

The unified native and Wasm suites cover line and token batching, explicit EOF,
size reporting, parallel windows, ordinary/255/signal/missing status classes,
and policy-denied launches. With `printf` allowed, Wasm stdin batches return
the expected output; the same child under a read-only policy returns status
126 and a permission diagnostic.

## Consequences

Pipeline composition is useful without shell injection, bounded parallelism is
observable, and policy denial is explicit.

## Rollback

Extend scheduling only with explicit concurrency/cancellation policy probes;
the current contract deliberately uses batch-window cancellation boundaries
instead of process-group cancellation.
