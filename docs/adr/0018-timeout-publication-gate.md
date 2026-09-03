# ADR-0018: Keep Timeout Local-Only Behind Process-Group Cancellation

Status: Accepted
Date: 2026-09-03

## Context

The upstream default requires process-group cancellation. The portable runtime
currently provides only direct-child cancellation.

## Decision

Keep `timeout` in the local 48-command build. A local Wasm expiry returned 124,
but no `cli/timeout` MoonX publication is made until a pure portable
process-group primitive exists.

## Consequences

The 47-command registry count is honest and no C/FFI workaround is introduced.

## Rollback

Revisit the publication gate only with a new capability and black-box signal
tests for descendants and cleanup.
