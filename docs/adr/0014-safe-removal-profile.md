# ADR-0014: Keep Root and Current-Directory Removal Protection

Status: Accepted
Date: 2026-09-03

## Context

Wasm policy roots and the caller's working directory are safety boundaries.
Removing them would make a command invocation destructive beyond its operand.

## Decision

Support file/tree removal with `-r/-R`, `-f`, `-d`, and `-v`, while refusing
filesystem roots, the current directory, and normalized ancestors.

## Evidence

An isolated Wasm tree removal returned status 0 and removed only that tree.

## Consequences

Normal cleanup works while catastrophic broad operands fail closed.

## Rollback

Never disable the guard globally. A caller needing broader cleanup must supply
a narrower policy root and explicit operands.
