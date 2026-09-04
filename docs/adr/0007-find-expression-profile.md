# ADR-0007: Bounded Find Expression and Action Profile

Status: Accepted
Date: 2026-09-04

## Context

Findutils has a large expression language and actions that can launch
processes. A partial parser must not silently reinterpret unsupported forms.

## Decision

Support path/name/type/depth predicates, boolean `!/-a/-o`, `-print`,
`-print0`, metadata predicates `-empty/-size/-mtime/-newer`, `-prune`,
postorder `-delete`, and direct one-child or deterministic batched
`-exec ... ;/+`. File and process policy remains required for the
corresponding operations. The profile does not follow symlinks, expose
ownership/link-target predicates, or claim the complete findutils expression
language.

## Evidence

Native and Wasm runner probes cover metadata matching, preorder pruning,
postorder deletion, deterministic batching, child-policy denial, and
no-side-effect parser failures. The pinned findutils oracle remains the
differential baseline for the accepted subset.

## Consequences

Common discovery and disposable-tree scripts work without a host find binary,
while unsupported expressions and policy-denied actions fail closed instead
of producing a plausible wrong traversal or mutation.

## Rollback

Extend the grammar only with a positive and negative Wasm fixture for each new
predicate or action.
