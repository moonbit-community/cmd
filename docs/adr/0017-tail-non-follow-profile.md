# ADR-0017: Publish Tail Without Follow-Mode Claims

Status: Accepted
Date: 2026-09-03

## Context

`tail -f/-F` requires long-lived file notifications, reopen semantics, and
signal handling that are not part of the portable Wasm contract.

## Decision

Support line/byte selection, positive offsets, and `-q/-v`. Do not claim follow
mode or fabricate polling semantics.

## Evidence

Wasm probes for `-n`, `-c`, and `+K` returned the expected suffix/prefix output
with status 0.

## Consequences

Log slicing is predictable; live log following remains outside this artifact.

## Rollback

Add follow only after a cross-target notification/reopen probe and cancellation
contract are accepted.
