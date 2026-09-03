# ADR-0022: Keep Xargs Direct-Child Execution Policy-Visible

Status: Accepted
Date: 2026-09-03

## Context

`xargs` turns input into process argv batches. Allowing arbitrary ambient
program execution would bypass Wasm policy.

## Decision

Support whitespace/NUL parsing, `-0`, `-r`, `-t`, `-n`, and `-I`. Execute each
batch as one direct child request. Leave child-status mapping, `-L`, `-P`, EOF
strings, and unverified size/signal forms outside the claim.

## Evidence

With `printf` allowed, Wasm stdin batches returned `<a>`/`<b>` output and
status 0. The same child under a read-only policy returned status 126 and a
permission diagnostic; the remaining nonzero child-status mapping is
unverified.

## Consequences

Pipeline composition is useful without shell injection, and policy denial is
observable.

## Rollback

Extend scheduling only with explicit concurrency/cancellation policy probes.
