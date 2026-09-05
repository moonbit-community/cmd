# ADR-0003: Deterministic Streams

Status: Accepted  
Date: 2026-09-05

## Context

Commands are composed through pipes, files, and explicit `-` operands. Host
terminal behavior and locale-sensitive records are not portable across Native
and Wasm.

## Decision

Keep implicit stdin byte-clean and silent. Use a fixed C-locale byte contract
for the text pipeline (`grep`, `sort`, `uniq`, `wc`, `tr`, and related record
operations). Keep sorting in-process with bounded memory. `tail -f` follows an
already-open regular-file descriptor by polling; `tail -F` path reopen and
rotation are rejected until a portable identity and cancellation contract
exists.

## Consequences

The same bytes flow through terminal, pipe, redirection, and explicit `-`
paths. Locale-aware collation, external sort files, dynamic progress meters,
and path-follow rotation are outside the claimed profile.

## Evidence

The P2/P3 manifest cases exercise binary/NUL records, C-locale ordering, and
the retained `tail -F` rejection.

## Revisit when

The runtime offers a stable locale/identity/reopen primitive and a bounded
resource contract for external streams.
