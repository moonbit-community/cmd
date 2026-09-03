# ADR-0007: Bounded Find Expression and Action Profile

Status: Accepted
Date: 2026-09-03

## Context

Findutils has a large expression language and actions that can launch
processes. A partial parser must not silently reinterpret unsupported forms.

## Decision

Support path/name/type/depth predicates, boolean `!/-a/-o`, `-print`,
`-print0`, and one-child `-exec ... ;`. Require file/process policy for the
corresponding operations and reject unverified batching/deletion/link/time
forms.

## Evidence

Wasm absolute-path probes returned matching `-name`, `-type`, depth, NUL, and
recursive results with status 0.

## Consequences

Common discovery scripts work without a host find binary, while unsupported
expressions fail closed instead of producing a plausible wrong traversal.

## Rollback

Extend the grammar only with a positive and negative Wasm fixture for each new
predicate or action.
