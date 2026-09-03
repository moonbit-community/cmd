# ADR-0004: Copy Data Without Inventing Metadata Preservation

Status: Accepted
Date: 2026-09-03

## Context

The portable filesystem surface can copy bytes and walk directories, but does
not provide complete portable link, owner, mode, timestamp, and special-file
metadata operations.

## Decision

`cp` copies regular files and directory trees with `-R`, overwrite controls,
`-T`, and `-v`. `-a` and `-p` fail before creating output. Symlink and special
file preservation is not emulated.

## Evidence

Absolute-path Wasm probes copied a file and tree with status 0. `cp -p` returned
nonzero and created no preservation output.

## Consequences

Byte content is portable and side effects are predictable; callers must not
expect archive-level metadata.

## Rollback

Add preservation options only when each metadata primitive has a repeatable
native and Wasm probe.
