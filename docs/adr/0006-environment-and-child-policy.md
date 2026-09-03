# ADR-0006: Explicit Child Execution at the Wasm Boundary

Status: Accepted
Date: 2026-09-03

## Context

`env`, `sh`, `make`, `find`, `xargs`, and `timeout` launch programs. Wasm must
not inherit an ambient process authority that the caller did not grant.

## Decision

Every child launch is a separate MoonBit process request evaluated by the
Wasm policy. Wasm starts from its policy environment and applies command
changes. A denied child is an authorization failure with its command-specific
status; native inheritance is outside this Wasm support record.

## Evidence

`env -i FOO=bar` returned `FOO=bar` in Wasm. `xargs` returned child output when
`printf` was allowed and status 126/permission diagnostics when it was not.

## Consequences

The same command can be semantically valid but operationally denied by a host
policy. Documentation records these outcomes separately.

## Rollback

Do not remove the boundary. A future host may broaden the explicit policy
schema while preserving the command API.
