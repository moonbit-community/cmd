# ADR-0025: Use a C-Locale Byte Record Profile

Status: Accepted
Date: 2026-09-04

## Context

`grep`, `sort`, `uniq`, `wc`, and `head` must handle arbitrary command-stream
bytes and NUL-delimited records on both native and Wasm targets. Host locale
tables and implicit UTF-8 decoding would make ordering, offsets, malformed
input, and character classes target-dependent.

## Decision

Define the P2/P3 text pipeline against `LC_ALL=C`. Record delimiters, byte
offsets, ASCII blank/case/dictionary/nonprinting transforms, and malformed
input handling operate on bytes. `wc -m` remains the explicit valid-UTF-8
character counter; `wc -L` uses ASCII display width and eight-column tabs.

Line/NUL readers share the existing stream scanner with an explicit delimiter.
Commands preserve record data and emit the selected line or NUL terminator
without converting payloads through a host locale.

## Evidence

The unified native suite covers binary/NUL, empty, malformed, repeated-option,
file/stdin, alignment, and large-input cases. The pinned oracle manifest adds
strict GNU comparisons for context output, binary policy, key modes, NUL
records, file lists, count forms, and headers. Wasm policy tests run the same
file-oriented options under denied and allowed roots.

## Consequences

The profile is deterministic across supported targets but does not claim
locale-aware collation, Unicode display width, or non-C character classes.

## Rollback

Add locale-aware behavior only behind an explicit portable locale contract and
retain these byte cases as the C-locale branch.
