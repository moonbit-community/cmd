# ADR-0011: Deterministic Portable Ls Output

Status: Accepted
Date: 2026-09-03

## Context

Long listings require portable ownership, mode, time, colour, and terminal
format metadata that is not guaranteed by the runtime.

## Decision

Support hidden/explicit directory selection, type indicators, one-entry lines,
and recursion with deterministic ordering. Do not synthesize long metadata.

## Evidence

Wasm probes with `-a -F` and `-R -1` returned hidden entries, indicators, and
recursive paths with status 0.

## Consequences

Scripts receive stable names and types; interactive long-format parity remains
unclaimed.

## Rollback

Add a long format only with a cross-target metadata fixture, not by formatting
host-specific guesses.
