# ADR-0023: Verify Forward Hex and Positive Seeks Only

Status: Accepted
Date: 2026-09-03

## Context

`xxd` has addressed reverse patching and negative/end-relative seeks whose
semantics depend on random-access guarantees and precise file mutation.

## Decision

Support forward hex, plain/reverse mode, columns, length, and positive `-s`.
Do not claim negative seeks or addressed reverse patching until separately
probed.

## Evidence

Wasm forward, plain, reverse, length, and positive-seek fixtures returned
status 0 and the expected bytes.

## Consequences

Hex inspection and common reverse conversion are portable; patching remains
explicitly partial.

## Rollback

Add addressed writes only with side-effect and malformed-input probes.
