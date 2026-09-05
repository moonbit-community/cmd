# ADR-0002: Harness Owns Policy

Status: Accepted  
Date: 2026-09-05

## Context

Wasm commands run inside a host-controlled capability boundary. Duplicating
that policy inside each command would make semantic compatibility depend on an
unreviewed second authorization layer.

## Decision

The harness supplies file, process, and network policy through `moonrun
--policy`. Commands request ordinary operations and do not bypass, weaken, or
reimplement the policy. The runner records an authorization failure separately
from a parser or semantic failure, and policy denial must leave no forbidden
mutation.

## Consequences

Native tests establish command behavior; Wasm policy tests establish the
allowed and denied capability surface. `timeout` remains local-only because a
published process-group cancellation capability is unavailable. A policy
failure is not evidence that a command option is unsupported.

## Evidence

`tests/runner/policy.mbt` covers file, process, network, permission, and
mutation cases against pre-built Wasm artifacts.

## Revisit when

MoonBit exposes a stable capability API that changes the published policy
contract or provides process-group cancellation.
