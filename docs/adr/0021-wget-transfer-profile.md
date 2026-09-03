# ADR-0021: Support HTTP Transfer Controls, Not Recursive Mirroring

Status: Accepted
Date: 2026-09-03

## Context

Wget's recursive mirror mode is a crawler with URL rewriting, content-type
handling, and persistent state, not a single HTTP transfer.

## Decision

Keep pure MoonBit HTTP/HTTPS transfers with the observed quiet mode, output
selection, a POST body path, and invalid idle-timeout input. Input URL files,
resume/timestamp controls, headers/method edge cases, retries, redirects,
proxy/TLS controls, successful timeout expiry, and other help-visible options
remain unverified. Do not claim recursive mirroring, cookies/auth/HSTS,
non-HTTP protocols, or exact native progress bytes.

## Evidence

Wasm probes for stdout/file output, POST, and 404 returned status 0/8 as
documented; `-q` suppressed transfer feedback.

## Consequences

Common downloads are script-compatible without a host wget, while mirror users
see a clear documented boundary.

## Rollback

Narrow an option only after a repeatable artifact probe regresses it; add
mirroring as a separate design, not an implicit fallback.
