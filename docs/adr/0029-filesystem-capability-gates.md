# ADR-0029: Gate Metadata-Dependent Filesystem Options

Status: Accepted
Date: 2026-09-05

## Context

The runtime exposes portable kind, size, and timestamp reads, but not verified
permission reads, timestamp setters, hard links, readlink, cross-device
classification, or special-file policy across all supported targets.

## Decision

Publish explicit capability predicates in `core/platform`. Commands continue to
reject metadata-preserving, symbolic/reference mode, timestamp-selection,
hard-link, readlink, special-file, and cross-device fallback options before
side effects until the corresponding predicate is proven.

## Evidence

Cross-target platform tests assert the capability matrix; existing command
negative fixtures verify no-side-effect rejection.

## Consequences

The P8 track produces an auditable gate instead of guessing host metadata or
weakening Wasm isolation.

## Rollback

Keep the explicit rejection and update the support record if a target loses a
runtime primitive.
