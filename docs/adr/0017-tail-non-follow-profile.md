# ADR-0017: Portable Tail Follow Mode

Status: Accepted
Date: 2026-09-03

## Context

`tail -f` is a long-lived operation. A portable implementation must avoid
assuming inotify, kqueue, ReadDirectoryChangesW, or another host notification
API. `tail -F` additionally requires path re-open and stable file identity
semantics that are not exposed by the shared filesystem contract.

## Decision

Support line/byte selection, positive offsets, `-q/-v`, and descriptor-follow
with `-f/--follow`. Follow regular files by polling `File::size()` and reading
new bytes with `read_at`; use `-s/--sleep-interval` for a non-negative finite
poll interval, defaulting to one second. A size decrease resets the descriptor
offset to zero without a diagnostic. Followed stdin and pipes stop at EOF.
Do not implement or claim `-F` path-follow semantics.

## Evidence

Native compatibility sessions and the Linux GNU differential cover initial
tail output, line/byte appends, no-newline appends, truncation recovery,
multiple files, headers, stdin EOF, interval parsing, and cancellation. The
same append/truncate session is also run against the release Wasm artifact
before this capability is published in the support matrix.

P3 repeated the `-F` rejection probe. The shared filesystem API still exposes
size and descriptor reads but no cross-target stable file identity, so the
reopen prerequisite remains unsatisfied.

## Consequences

Log slicing and portable polling are predictable. Descriptor-follow does not
switch to a newly-created path after rotation; that remains outside this
artifact until a cross-target file-identity contract exists.

## Rollback

Add `-F` only after a cross-target file-identity/reopen probe and an explicit
cancellation contract are accepted.
