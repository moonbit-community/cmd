# ADR-0013: Preserve Source When Rename Cannot Be Classified

Status: Accepted
Date: 2026-09-03

## Context

The portable filesystem API does not expose a reliable cross-device (`EXDEV`)
discriminator or complete metadata copy operation.

## Decision

`mv` uses the policy-checked rename path and supports `-f/-n/-T/-v`. It does
not fall back to copy-and-delete on an unclassified failure.

## Evidence

Absolute-path Wasm file and verbose probes returned status 0 and moved the
source. The command reports a failed rename without claiming a copied result.

## Consequences

The source is not silently destroyed when the runtime cannot classify a move.

## Rollback

Add fallback only with a portable `EXDEV` and metadata-preservation probe.
