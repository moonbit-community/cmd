# ADR-0015: Interpret Shell Syntax Without Delegating a Script

Status: Accepted
Date: 2026-09-03

## Context

`sh` must offer shell-like quoting, variables, conditionals, pipelines, and
redirections, but delegating a whole script to `/bin/sh` would violate pure
MoonBit and bypass Wasm policy.

## Decision

Interpret the supported grammar in MoonBit and launch each external command as
an explicit child request. `-c`, `-s`, script selection, and positional values
are part of the observed surface. Unsupported language forms fail closed.

## Evidence

Wasm probes verified variables, pipelines, redirections, script/stdin
selection, and positional parameters. Command substitution returned status 2.
A child outside the process policy returned a permission diagnostic rather than
escaping the boundary.

## Consequences

Scripts are portable within the documented grammar and policy. This is not a
Bash implementation.

## Rollback

Extend syntax only with a direct-interpreter fixture; never add host-shell
delegation as a compatibility shortcut.
