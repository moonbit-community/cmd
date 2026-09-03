# ADR-0005: Pure-MoonBit HTTP Client Profile

Status: Accepted
Date: 2026-09-03

## Context

`curl` and `wget` need streaming bodies, status handling, redirects, progress,
and timeouts, while the project must remain C-free and usable as Wasm.

## Decision

Use the shared MoonBit `netops` path for HTTP/HTTPS. The observed profile covers
GET, HEAD, POST, redirects, file/stdout output, status failures, and invalid
idle-timeout rejection. Successful inactivity expiry, retry, proxy, and TLS
controls remain help-visible but unverified.
Keep non-HTTP protocols, recursive mirroring, auth/cookie state, and exact
native wire diagnostics outside the claimed profile.

## Evidence

Wasm probes against `example.com` and `httpbin.org` returned body/status output
for GET, HEAD, redirect, POST, file output, and 404 (`curl` 22, `wget` 8).

## Consequences

The commands are deployable without a host curl/wget executable. Their support
record is a useful HTTP subset, not a claim of protocol-family parity.

## Rollback

Revert only by retaining the pure MoonBit path and narrowing the documented
option surface; never silently delegate to a host command.
