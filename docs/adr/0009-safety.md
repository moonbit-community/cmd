# ADR-0009: Fail Before Mutation

Status: Accepted  
Date: 2026-09-05

## Context

Filesystem commands can otherwise leave a partial tree, delete a source, or
overwrite a target before discovering an unsupported link, cycle, policy, or
rename condition.

## Decision

Preflight complete copy/link trees, nested destinations, cycles, special files,
and policy-sensitive operations before writing. `rm` protects the root and
current directory. `mv` never guesses an EXDEV fallback and preserves the
source when rename cannot complete. Interactive/update/backup decisions are
made before an actual overwrite.

## Consequences

An unsupported operation fails closed with deterministic status and no forbidden
target, backup, or source mutation. The behavior may be narrower than GNU, but
it is auditable across Native and Wasm.

## Evidence

The unified runner captures filesystem snapshots and includes nested-target,
cycle, policy-denial, update, backup, and protected-path cases. Remaining P8
side-effect probes are listed in the plan's gap register.

The published-version Runner applies the same invariant to each candidate and
oracle copy: the working directory remains alive until both processes,
snapshots and reports complete. Registry/transport failures are explicit
infrastructure failures, never skips, and failed cases must not leave target,
backup or source mutations.

## Revisit when

The runtime exposes a reliable atomic transaction or cross-device classification
that can preserve these guarantees.
