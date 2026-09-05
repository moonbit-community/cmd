# ADR-0030: Maximum Portable Native/Wasm Filesystem Subset

Status: Accepted
Date: 2026-09-05

## Context

The public `moonbitlang/async/fs@0.21.x` API exposes file kinds, regular-file
size, access checks, symbolic-link creation, and atime/mtime/ctime reads on the
supported Native and Wasm targets. It does not expose reliable timestamp
setters, permission reads, hard-link/readlink primitives, special-file creators,
or an EXDEV discriminator. Importing `async/internal` is prohibited by MoonBit
module visibility.

## Decision

Implement the largest strict common subset in pure MoonBit. Shared `core/fsops`
types own nanosecond timestamp comparison, age buckets, update/backup decisions,
and complete copy preflight. Commands may add semantic logic around public
primitives, but must reject capabilities that cannot be implemented exactly.
`-H/-L/-P`, update/interactive/backup controls, time predicates/sorting, and
closed symbolic chmod assignments are supported within those limits.

## Consequences

Native and Wasm use one behavior contract and one prebuilt-artifact test path.
Policy remains a harness concern; policy suites verify both allowed and denied
operations. Rejections happen before mutation, and unsupported metadata/link
features remain visible in the capability matrix.

## Evidence

`moon check --target all --deny-warn`, package white-box tests, Native/Wasm
release builds, and the unified compatibility/policy runners are the required
acceptance evidence. The old all-closed P8 gate record is superseded by this
ADR; its hard boundaries remain binding.

## Rollback

If a public runtime primitive is removed or diverges across targets, remove only
the affected command claims and restore the corresponding pre-mutation gate.
