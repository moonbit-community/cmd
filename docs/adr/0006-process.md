# ADR-0006: Direct Child Processes

Status: Accepted  
Date: 2026-09-05

## Context

`sh`, `find -exec`, `xargs`, `make`, and `env` launch children. In Wasm those
launches must be explicit policy requests; ambient host shells and process
groups would undermine reproducibility and safety.

## Decision

Use direct child requests for all command execution. Keep `xargs -P` bounded
and deterministic, map child statuses explicitly, and keep recipe execution in
the MoonBit `sh`/`make` interpreters. Publish `timeout` only for local runs
until a portable process-group cancellation primitive exists.

## Consequences

Child policy is observable and tested separately. Shell-only expansions and
full GNU jobserver semantics are not silently inherited from the host.

## Evidence

P4/P5/P7 runner and policy cases cover allowed and denied children, status
classes, batching, recipes, and the local-only timeout boundary.

## Revisit when

The host supplies a stable process-group and cancellation contract for Wasm.
