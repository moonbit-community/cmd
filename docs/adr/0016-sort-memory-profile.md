# ADR-0016: Keep Sort In-Process on Wasm

Status: Accepted
Date: 2026-09-03

## Context

External temporary files and locale-dependent host sorting are not a stable
portable baseline for a Wasm command.

## Decision

Use the in-process line implementation for the observed `-r/-n/-u/-f/-k/-t`
surface. The artifact rejects `-i`. Compare strings under the documented
byte/C-locale profile and do not claim GNU external-sort behavior.

## Evidence

Wasm numeric/unique and keyed fixtures returned sorted output with status 0.

## Consequences

The common sort workflow is deterministic and policy-light, with explicit
resource limits supplied by the host.

## Rollback

Add external spilling only behind a separately audited portable filesystem
contract.
