# ADR-0005: Pure-MoonBit HTTP Client Profile

Status: Accepted (P1 implemented)
Date: 2026-09-04

## Context

`curl` and `wget` need streaming bodies, status handling, redirects, progress,
and timeouts, while the project must remain C-free and usable as Wasm.

## Decision

Use the shared MoonBit `netops` path for HTTP/HTTPS. The P1 profile covers all
accepted methods, streamed data and uploads, redirects, file/stdout output,
remote filename selection, resume/conditional transfers, retries, timeouts,
HTTP CONNECT proxies, TLS verification controls, partial-output cleanup, and
stable command-specific exit status mapping.

Redirect semantics remain adapter-specific. curl can preserve an explicit
method while distinguishing `--data-*` from upload bodies; Wget retains its
normal POST rewrite behavior. The shared layer removes authorization headers
when an origin changes.

Keep non-HTTP protocols, recursive mirroring, auth/cookie state, and exact
native wire diagnostics outside the claimed profile.

## Evidence

The unified native suite uses one in-memory HTTP fixture group plus a reusable
HTTPS and proxy fixture. It checks response bytes, status, stderr routing,
files, collisions, cleanup, redirects, retry attempts, and timeout expiry. The
policy suite runs the pre-built Wasm artifacts through `moonrun --policy` with
both a denied network profile and a profile restricted to `127.0.0.1:*`.

The pinned upstream manifest includes differential cases for explicit-method
redirects, binary data/body files, redirect limits, input URL files, range
resume, conditional 304, and content-disposition collisions.

## Consequences

The commands are deployable without a host curl/wget executable. Authorization
remains a harness responsibility and every socket operation stays visible to
the Wasm policy. Their support record is a useful HTTP subset, not a claim of
protocol-family parity.

## Rollback

Revert only by retaining the pure MoonBit path and narrowing the documented
option surface; never silently delegate to a host command.
