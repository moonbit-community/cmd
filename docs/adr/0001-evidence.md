# ADR-0001: Evidence First

Status: Accepted  
Date: 2026-09-05

## Context

The repository previously had several black-box test trees and treated help
output or parser branches as compatibility evidence. That made it possible for
the support matrix, tests, and published Wasm behavior to disagree.

## Decision

Use `tests/runner` as the only black-box entry point. Keep three explicit
suites: `compat` for native semantics and boundaries, `oracle` for the pinned
upstream comparison, and `policy` for Wasm authorization and mutation. Build
native and Wasm release artifacts once and pass their roots to the runner. The
manifest, captured status/stdout/stderr, and filesystem snapshot are the
evidence; `docs/compatibility.md` is the sole support record.

## Consequences

Every promoted option needs repeatable positive and negative evidence, with
policy tested separately from command semantics. A green smoke test or help
line cannot promote a claim. The retired `tests/cram`, `tests/compat`,
`tests/policy`, and `tests/oracle` entry points must not return.

## Evidence

The current manifest validates 48 commands and 141 cases. The runner README
documents the reusable-artifact contract and the exact commands.

## Revisit when

The runner no longer captures a required observable (status, bytes, or side
effects), or an upstream baseline changes.
