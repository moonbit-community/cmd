# ADR-0004: Portable Filesystem Subset

Status: Accepted  
Date: 2026-09-05

## Context

Native and Wasm expose different filesystem primitives. Pure MoonBit can read
file kind, regular-file size, access checks, and atime/mtime/ctime, and can
create symbolic links, but it cannot reliably set arbitrary timestamps, create
special files or hard links, read link targets, or classify EXDEV.

## Decision

Implement the largest strict subset from public `async/fs` APIs. Do not import
`async/internal`, add C stubs or custom Wasm imports, or delegate to a host
filesystem command. Shared
`core/fsops` code owns nanosecond comparison, age buckets, traversal policy,
backup/update decisions, and closed symbolic `chmod` assignment. `core/platform`
exposes fine-grained capability predicates. `test`, `find`, `ls`, `cp`, `mv`,
`chmod`, `ln`, and `touch` use those predicates and reject unavailable forms
before mutation. Copy traversal has explicit `-H/-L/-P` modes and cycle/nested-
target preflight.

## Consequences

The profile supports useful regular-file metadata and symlink behavior on both
targets without pretending to preserve ownership, mode text, blocks, links, or
timestamps. Numeric `chmod` remains supported; only explicit `=` assignments
for `u/g/o` are accepted for non-directory operands. `cp -p/-a`, hard links,
`readlink`, special-file creation, arbitrary `touch` setters, and cross-device
fallback remain rejected.

## Evidence

The P8 package tests and runner cases exercise size, links, sorting, update and
backup decisions, relative links, and policy-gated mutation. The P8 gap
register in the compatibility plan lists option families still needing direct
differential probes.

## Revisit when

Public MoonBit APIs provide a strict cross-target setter/identity primitive or
the project changes its portability target.
