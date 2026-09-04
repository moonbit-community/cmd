# ADR-0028: Extend Self-Contained make and xxd Profiles

Status: Accepted
Date: 2026-09-05

## Context

`make` and `xxd` are implemented in MoonBit and do not need host delegation.
Their next useful compatibility gaps are conditionals/pattern variables and
include/addressed hex workflows.

## Decision

Add bounded Make conditionals, pattern/static-pattern dependency expansion,
automatic variables, and explicit `-j/-k/-W` handling. Add xxd include output,
`--revert`, symbol naming, and validated addressed reverse patches. Keep
parallel scheduling sequential and reject negative seeks.

## Evidence

Package tests and unified manifest cases exercise positive output, status, and
malformed-input boundaries.

## Consequences

Common build and embedding scripts work without a host executable. Features
whose semantics require an unimplemented jobserver or end-relative stream
seek remain explicit boundaries.

## Rollback

Narrow the affected option surface and retain the fail-closed diagnostics.
