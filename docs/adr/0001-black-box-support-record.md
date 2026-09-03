# ADR-0001: Use Real Wasm Artifacts as the Support Authority

Status: Accepted
Date: 2026-09-03

## Context

The repository contains local source, tests, and publishable Wasm assets. A
source-level option parser is not proof that MoonX can execute the option, and
a native test does not prove Wasm policy behavior.

## Decision

Support claims are made only after invoking the Wasm artifact with
`moon run --target wasm --release`, capturing stdout, stderr, status, and side
effects. The unified support record uses `subset verified`, `restricted`,
`verified rejection`, and `local-only`; it never calls a smoke result full
upstream compatibility.

## Consequences

The record is reproducible and honest about unprobed options. A source change
requires a new black-box probe before its README or help text claims support.

## Rollback

Re-run the same cases against a replacement artifact and retain the previous
record until the new output is compared.
