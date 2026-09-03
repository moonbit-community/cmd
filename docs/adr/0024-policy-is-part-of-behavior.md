# ADR-0024: Record Wasm Authorization Separately From Command Semantics

Status: Accepted
Date: 2026-09-03

## Context

The same Wasm artifact can succeed under one policy and fail under another.
Treating a denied path as an unsupported parser would produce false support
claims.

## Decision

Every audit records the command result and the policy used. File read/write,
process allow-list, network, and permission failures are documented as
authorization boundaries. Functional rows are based on policy-enabled probes.

## Evidence

The same xargs and shell artifacts succeeded when `printf` was allowed and
returned permission diagnostics when it was denied; file probes likewise
changed from path errors to successful transforms when absolute paths were
inside the policy.

## Consequences

Users can distinguish “the command supports it” from “this host did not grant
it.”

## Rollback

Do not collapse policy errors into generic unsupported status; add clearer
policy diagnostics if needed.
