# ADR-0010: Support Symlinks and Fail Closed for Hard Links

Status: Accepted
Date: 2026-09-03

## Context

The portable API exposes symbolic-link creation but no verified hard-link
primitive across all targets.

## Decision

Implement `ln -s` with `-f`, `-T`, and `-v`. Reject `ln` without `-s` before
mutation.

## Evidence

Wasm symlink and force-replacement probes returned status 0 and the expected
link target. A hard-link probe returned nonzero and left no link.

## Consequences

Link behavior is explicit and portable; hard-link callers receive a clear
failure instead of a copied file.

## Rollback

Enable hard links only after a policy-visible primitive is available on every
target.
