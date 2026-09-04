# ADR-0021: Support HTTP Transfer Controls, Not Recursive Mirroring

Status: Accepted (P1 implemented)
Date: 2026-09-04

## Context

Wget's recursive mirror mode is a crawler with URL rewriting, content-type
handling, and persistent state, not a single HTTP transfer.

## Decision

Keep pure MoonBit HTTP/HTTPS transfers and certify the bounded single-transfer
surface: repeated input URL files, output/log selection, resume and conditional
requests, headers/method/body combinations, retries, redirects and duplicate
filenames, timeout controls, HTTP CONNECT proxies, and certificate verification
control. Do not claim recursive mirroring, cookies/auth/HSTS, non-HTTP
protocols, post-download timestamp restoration, or exact native progress bytes.

## Evidence

The unified native suite exercises each P1 family against reusable local
HTTP/HTTPS/proxy fixtures, including positive, invalid-input, failure-status,
and filesystem side-effect cases. The pinned upstream manifest covers input
files, binary bodies, repeated headers, range resume, conditional 304, and
content-disposition collision behavior. The Wasm policy suite proves both
denied networking and a local-only allowed endpoint using pre-built artifacts.

## Consequences

Common scripted downloads have repeatable compatibility evidence without a host
wget, while mirror users see a clear documented boundary. Network authorization
is supplied by the harness rather than embedded in the command.

## Rollback

Narrow an option only after a repeatable artifact probe regresses it; add
mirroring as a separate design, not an implicit fallback.
