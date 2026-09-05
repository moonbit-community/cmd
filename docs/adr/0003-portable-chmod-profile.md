# ADR-0003: Numeric Chmod Profile

Status: Accepted
Date: 2026-09-03

## Context

Portable permission APIs expose mutation but do not provide a verified,
cross-target read/modify/write primitive for symbolic modes or `--reference`.

## Decision

Accept numeric modes with `-R` and `-v`, plus complete symbolic `=` assignments
that explicitly cover `u`, `g`, and `o`. Reject incremental/reference requests
before mutation instead of guessing the current mode.

## Evidence

`moon run --target wasm --release commands/chmod -- -v 600 <file>` returned 0
and changed the file; the same artifact with `u+x` returned status 2.

## Consequences

The supported result is deterministic on policy-enabled hosts. Incremental
symbolic parity still waits for a portable permission-read API.

## Rollback

Expand the mode grammar only after a Wasm probe demonstrates read/modify/write
semantics on every supported target.
