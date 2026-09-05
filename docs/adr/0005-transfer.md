# ADR-0005: HTTP Transfer Profile

Status: Accepted  
Date: 2026-09-05

## Context

`curl` and `wget` have broad upstream protocols and terminal behaviors, while
the repository can provide a deterministic pure-MoonBit HTTP implementation.

## Decision

Publish a bounded HTTP/HTTPS profile: methods, bodies, files, redirects,
retries, timeouts, output naming, HTTP CONNECT proxy selection, and explicit
TLS verification controls. Keep local fixtures and network policy in the
runner. Do not delegate to host clients.

## Consequences

The commands remain useful for scripts while FTP/SFTP/SMTP, authentication and
cookie state, HTTP/2 negotiation, recursive mirroring, and exact progress or
diagnostic bytes remain outside the claim.

## Evidence

The phase2/P1 manifest contains 25 HTTP cases and reusable local HTTP/HTTPS and
proxy fixtures. Wasm policy cases cover denied networking and an allowed local
endpoint.

## Revisit when

A separate protocol and state model is designed and receives its own pinned
oracle suite.
