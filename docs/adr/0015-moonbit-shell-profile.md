# ADR-0015: Interpret Shell Syntax Without Delegating a Script

Status: Accepted
Date: 2026-09-03

## Context

`sh` must offer a portable POSIX shell slice, but delegating a whole script to
`/bin/sh` would violate pure MoonBit and bypass Wasm policy.

## Decision

Interpret the supported grammar in MoonBit and launch each external command as
an explicit child request. The P5 slice includes command substitution,
heredocs, conditionals, case, loops, functions, grouping, portable parameter
expansion, and `set` status options. Unsupported language forms fail closed.

## Evidence

Native and Wasm runner fixtures verify the P5 grammar and status cases. A child
outside the process policy returns a permission diagnostic rather than escaping
the boundary.

## Consequences

Scripts are portable within the documented grammar and policy. This is not a
Bash implementation.

## Rollback

Extend syntax only with a direct-interpreter fixture; never add host-shell
delegation as a compatibility shortcut.
